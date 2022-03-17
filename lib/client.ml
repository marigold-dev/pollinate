open Lwt_unix

type 'a t = {
  address : Address.t;
  socket : file_descr;
  state : 'a ref;
  request_inbox : Message.t Tqueue.t;
  response_inbox : Message.t Tqueue.t;
  recv_mutex : Lwt_mutex.t;
  state_mutex : Lwt_mutex.t;
}

let address_of { address; _ } = address

let peer_from { address; _ } = Peer.from address

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
  Lwt.return (msg_buffer, Peer.from_socket_address addr)

let next_request client = Tqueue.take_opt !client.request_inbox
let next_response client = Tqueue.take_opt !client.response_inbox

let request client request peer =
  let%lwt () = send_to client request peer in
  Tqueue.wait_to_take !client.response_inbox

let route client peer msg router =
  let open Message in
  let msg = router peer msg in
  match msg.label with
  | Message.Request -> Tqueue.add msg !client.request_inbox
  | Message.Response -> Tqueue.add msg !client.response_inbox

let serve client router msg_handler =
  let rec server () =
    let%lwt message, peer = recv_next client in
    let%lwt () = route client peer message router in

    let%lwt request = next_request client in

    let%lwt () =
      match request with
      | Some request ->
        let%lwt () = Lwt_mutex.lock !client.state_mutex in
        let response = msg_handler !client.state request in
        let%lwt () = send_to client response peer in
        Lwt.return (Lwt_mutex.unlock !client.state_mutex)
      | None -> Lwt.return () in

    server () in
  Lwt.async server

let init ~state ?router ~msg_handler (address, port) =
  let open Util in
  let router =
    match router with
    | Some router -> router
    | None ->
      fun sender payload ->
        Message.{ label = Message.Response; sender; payload } in
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
        request_inbox = Tqueue.create ();
        response_inbox = Tqueue.create ();
        recv_mutex;
        state_mutex;
      } in
  serve client router msg_handler;
  Lwt.return client