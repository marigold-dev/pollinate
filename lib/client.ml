open Lwt_unix

type 'a t = {
  address : Address.t;
  socket : file_descr;
  state : 'a ref;
  recv_mutex : Lwt_mutex.t;
  state_mutex : Lwt_mutex.t;
}

let address_of { address; _ } = address

let peer_from { address; _ } =
  let open Peer in
  { address; status = Alive }

let send_to client payload peer =
  let open Peer in
  let len = Bytes.length payload in
  let addr = Address.to_sockaddr peer.address in
  let%lwt _ = sendto !client.socket payload 0 len [] addr in
  Lwt.return ()

let naive_broadcast client payload peers =
  let _ = List.map (send_to client payload) peers in
  Lwt.return ()

let recv_next client =
  let open Lwt_unix in
  let open Util in
  (* Peek the first 8 bytes of the incoming datagram
     to read the Bin_prot size header. *)
  let size_buffer = Bytes.create Encoding.size_header_length in
  let%lwt () = Lwt_mutex.lock !client.recv_mutex in
  (* Flag MSG_PEEK means: peeks at an incoming message.
     The data is treated as unread and the next recvfrom()
     or similar function shall still return this data.
     Here, we only need the mg_size.
  *)
  let%lwt _ =
    recvfrom !client.socket size_buffer 0 Encoding.size_header_length [MSG_PEEK]
  in
  let msg_size =
    Encoding.read_size_header size_buffer + Encoding.size_header_length in
  let msg_buffer = Bytes.create msg_size in
  (* Now that we have read the header and the message size, we can read the message *)
  let%lwt _, addr = recvfrom !client.socket msg_buffer 0 msg_size [] in
  Lwt_mutex.unlock !client.recv_mutex;
  Lwt.return (msg_buffer, Peer.peer_from_socket_address addr)

let serve client msg_handler =
  let rec server () =
    let%lwt request, peer = recv_next client in
    let%lwt () = Lwt_mutex.lock !client.state_mutex in
    let response = msg_handler !client.state peer request in
    let%lwt () = send_to client response peer in
    Lwt_mutex.unlock !client.state_mutex;
    server () in
  Lwt.async server

let init ~state ~msg_handler (address, port) =
  let open Util in
  let%lwt socket = Net.create_socket port in
  let state = ref state in
  let recv_mutex = Lwt_mutex.create () in
  let state_mutex = Lwt_mutex.create () in
  let client =
    ref
      {
        address = Address.create address port;
        socket;
        state;
        recv_mutex;
        state_mutex;
      } in
  serve client msg_handler;
  Lwt.return client
