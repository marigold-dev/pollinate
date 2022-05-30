open Lwt_unix
open Common
open Common.Util
open Types

let address_of { address; _ } = address

let peer_from { address; peers; _ } =
  Peer.
    {
      address;
      status = Alive;
      last_suspicious_status = None;
      neighbors = peers;
    }

let add_peer node (peer : Peer.t) =
  Base.Hashtbl.add node.peers ~key:peer.address ~data:peer

let create_request node recipient (payload, payload_signature) =
  Mutex.with_lock !node.current_request_id (fun id ->
      id := !id + 1;
      Lwt.return
        Message.
          {
            category = Message.Request;
            sub_category_opt = None;
            id = !id;
            sender = !node.address;
            recipient;
            payload;
            payload_signature;
          })

let create_response node request (payload, payload_signature) =
  Message.
    {
      category = Message.Response;
      sub_category_opt = None;
      id = request.id;
      sender = !node.address;
      recipient = request.sender;
      payload;
      payload_signature;
    }

let send_to node message =
  let open Message in
  let payload = Encoding.pack Message.bin_writer_t message in
  let len = Bytes.length payload in
  let addr = Address.to_sockaddr message.recipient in
  Mutex.unsafe !node.socket (fun socket ->
      let%lwt _ = sendto socket payload 0 len [] addr in
      Lwt.return ())

let recv_next node =
  let open Lwt_unix in
  let open Util in
  (* Peek the first 8 bytes of the incoming datagram
     to read the Bin_prot size header. *)
  let size_buffer = Bytes.create Encoding.size_header_length in
  let%lwt node_socket = Mutex.lock !node.socket in
  (* Flag MSG_PEEK means: peeks at an incoming message.
     The data is treated as unread and the next recvfrom()
     or similar function shall still return this data.
     Here, we only need the mg_size.
  *)
  let%lwt _ =
    recvfrom node_socket size_buffer 0 Encoding.size_header_length [MSG_PEEK]
  in
  let msg_size =
    Encoding.read_size_header size_buffer + Encoding.size_header_length in
  let msg_buffer = Bytes.create msg_size in
  (* Now that we have read the header and the message size, we can read the message *)
  let%lwt _ = recvfrom node_socket msg_buffer 0 msg_size [] in
  let message = Encoding.unpack Message.bin_read_t msg_buffer in
  Mutex.unlock !node.socket;
  Lwt.return message

let request node (request, payload_signature) recipient =
  let%lwt message = create_request node recipient (request, payload_signature) in
  let%lwt () = send_to node message in
  let condition_var = Lwt_condition.create () in
  Hashtbl.add !node.request_table message.id condition_var;
  Lwt_condition.wait condition_var

let broadcast_request node recipients (req, payload_signature) =
  List.map (request node (req, payload_signature)) recipients
