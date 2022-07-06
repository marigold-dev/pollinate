open Common
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

let add_peer node address =
  let peer = Peer.from address in
  Base.Hashtbl.add node.peers ~key:address ~data:peer

let add_peer_as_is node (peer : Peer.t) =
  Base.Hashtbl.add node.peers ~key:peer.address ~data:peer

let peers node = Base.Hashtbl.keys node.peers

let create_request node ?(request_ack = false) recipient ?payload_signature
    payload =
  Mutex.with_lock !node.current_request_id (fun id ->
      id := !id + 1;
      Lwt.return
        Message.
          {
            category = Message.Request;
            sub_category_opt = None;
            request_ack;
            id = !id;
            timestamp = Unix.gettimeofday ();
            sender = !node.address;
            recipients = [recipient];
            payload;
            payload_signature_opt = payload_signature;
          })

let create_response node ?(request_ack = false) request ?payload_signature
    payload =
  Message.
    {
      category = Message.Response;
      sub_category_opt = None;
      request_ack;
      id = request.id;
      timestamp = Unix.gettimeofday ();
      sender = !node.address;
      recipients = [request.sender];
      payload;
      payload_signature_opt = payload_signature;
    }

let create_post node ?(request_ack = false) ?payload_signature payload =
  Message.
    {
      category = Message.Post;
      request_ack;
      id = -1;
      sub_category_opt = None;
      timestamp = Unix.gettimeofday ();
      sender = !node.address;
      recipients = [];
      payload;
      payload_signature_opt = payload_signature;
    }

let create_ack node incoming_message =
  Message.
    {
      category = Message.Acknowledgment;
      sub_category_opt = None;
      request_ack = false;
      id = -1;
      timestamp = Unix.gettimeofday ();
      sender = !node.address;
      recipients = [incoming_message.sender];
      payload = incoming_message |> Message.hash_of |> Bytes.of_string;
      payload_signature_opt = None;
    }

let request node recipient ?payload_signature payload =
  let%lwt message = create_request node recipient ?payload_signature payload in
  let%lwt () = Networking.send_to node message in
  let condition_var = Lwt_condition.create () in
  Hashtbl.add !node.request_table message.id condition_var;
  Lwt_condition.wait condition_var

let post node message =
  !node.disseminator <- Disseminator.post !node.disseminator message
