open Lwt_unix
open Util

type 'a t = {
  address : Address.t;
  (* An ID that is incremented whenever a request is
     made from this client. The response matching this
     request will carry the same ID, allowing the response
     to be identified and thus stopping the request from
     blocking. *)
  current_request_id : int ref Mutex.t;
  (* A hashtable that pairs request IDs with condition variables.
     When a response is received by the server, it checks this table
     for a waiting request and signals the request's condition variable
     with the incoming response. *)
  request_table : (int, Message.t Lwt_condition.t) Hashtbl.t;
  socket : file_descr Mutex.t;
  state : 'a ref Mutex.t;
  (* A store of incoming messages for the client. Stores
     messages separately by category. *)
  inbox : Inbox.t;
}

let address_of { address; _ } = address

let peer_from { address; _ } = Peer.from address

let create_request client recipient payload =
  Mutex.with_lock !client.current_request_id (fun id ->
      id := !id + 1;
      Lwt.return
        Message.
          {
            category = Message.Request;
            id = !id;
            sender = !client.address;
            recipient;
            payload;
          })

let create_response client request payload =
  Message.
    {
      category = Message.Response;
      id = request.id;
      sender = !client.address;
      recipient = request.sender;
      payload;
    }

let send_to client message =
  let payload = Encoding.pack Message.bin_writer_t message in
  let len = Bytes.length payload in
  let addr = Address.to_sockaddr message.recipient in
  Mutex.unsafe !client.socket (fun socket ->
      let%lwt _ = sendto socket payload 0 len [] addr in
      Lwt.return ())

let recv_next client =
  let open Lwt_unix in
  let open Util in
  (* Peek the first 8 bytes of the incoming datagram
     to read the Bin_prot size header. *)
  let size_buffer = Bytes.create Encoding.size_header_length in
  let%lwt client_socket = Mutex.lock !client.socket in
  (* Flag MSG_PEEK means: peeks at an incoming message.
     The data is treated as unread and the next recvfrom()
     or similar function shall still return this data.
     Here, we only need the mg_size.
  *)
  let%lwt _ =
    recvfrom client_socket size_buffer 0 Encoding.size_header_length [MSG_PEEK]
  in
  let msg_size =
    Encoding.read_size_header size_buffer + Encoding.size_header_length in
  let msg_buffer = Bytes.create msg_size in
  (* Now that we have read the header and the message size, we can read the message *)
  let%lwt _ = recvfrom client_socket msg_buffer 0 msg_size [] in
  let message = Encoding.unpack Message.bin_read_t msg_buffer in
  Mutex.unlock !client.socket;
  Lwt.return message

let request client request recipient =
  let%lwt message = create_request client recipient request in
  let%lwt () = send_to client message in
  let condition_var = Lwt_condition.create () in
  Hashtbl.add !client.request_table message.id condition_var;
  Lwt_condition.wait condition_var

let broadcast_request client req recipients =
  List.map (request client req) recipients

let route client router msg =
  let open Message in
  let msg = router msg in
  Inbox.push !client.inbox msg.category msg

(* Signals a waiting request with its corresponding response
   if it exists. Otherwise returns None. *)
let handle_response request_table res =
  let open Message in
  let* res in
  let* waiting_request = Hashtbl.find_opt request_table res.id in
  Some (Lwt_condition.signal waiting_request res)

(* Sever procedure:
   1. Receive the next incoming message
   2. Route the message
   3. Grab the next response if it exists and send it to the request waiting for it
   4. Grab the next request if it exists and send it to the message handler along with the
     client's state
   5. Send the encoded response from the message handler to the requester *)
let serve client router msg_handler =
  let rec server () =
    let%lwt message = recv_next client in
    let%lwt () = route client router message in

    let%lwt next_response = Inbox.next !client.inbox Message.Response in
    let _ = handle_response !client.request_table next_response in

    let%lwt request = Inbox.next !client.inbox Message.Request in
    let%lwt () =
      match request with
      | Some request ->
        let%lwt state = Mutex.lock !client.state in
        let response =
          request |> msg_handler state |> create_response client request in
        let%lwt () = send_to client response in
        Lwt.return (Mutex.unlock !client.state)
      | None -> Lwt.return () in

    server () in
  Lwt.async server

let init ~state ?(router = fun m -> m) ~msg_handler (address, port) =
  let open Util in
  let address = Address.create address port in
  let current_request_id = Mutex.create (ref 0) in
  let request_table = Hashtbl.create 20 in
  let%lwt socket = Net.create_socket port in
  let socket = Mutex.create socket in
  let state = Mutex.create (ref state) in
  let inbox = Inbox.create () in
  let client =
    ref { address; current_request_id; request_table; socket; state; inbox }
  in
  serve client router msg_handler;
  Lwt.return client