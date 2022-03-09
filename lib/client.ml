open Lwt_unix

type 'a t = {
  address : string;
  port : int;
  socket : file_descr;
  state : 'a ref;
  recv_mutex : Lwt_mutex.t;
  state_mutex : Lwt_mutex.t;
}

let peer_from (client : 'a t) =
  Peer.{ address = client.address; port = client.port }

let send_to client payload peer =
  let len = Bytes.length payload in
  let addr = Peer.to_sockaddr peer in
  let%lwt _ = sendto !client.socket payload 0 len [] addr in
  Lwt.return ()

let recv_next client =
  let open Lwt_unix in
  let open Util.Encoding in
  let%lwt () = Lwt_mutex.lock !client.recv_mutex in
  let%lwt _ =
    recvfrom !client.socket bin_prot_buffer read_from_first_byte
      bin_prot_buffer_size [MSG_PEEK] in
  let msg_size = read_size_header bin_prot_buffer + bin_prot_buffer_size in
  let msg_buff = Bytes.create msg_size in
  let%lwt _, addr =
    recvfrom !client.socket msg_buff read_from_first_byte msg_size [] in
  Lwt_mutex.unlock !client.recv_mutex;
  Lwt.return (msg_buff, Peer.from_sockaddr addr)

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
  let open Util.Net in
  let%lwt socket = create_socket port in
  let state = ref state in
  let recv_mutex = Lwt_mutex.create () in
  let state_mutex = Lwt_mutex.create () in
  let client = ref { address; port; socket; state; recv_mutex; state_mutex } in
  serve client msg_handler;
  Lwt.return client
