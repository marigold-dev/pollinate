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
            timestamp = Unix.gettimeofday ();
            sender = !node.address;
            recipients = [recipient];
            payload;
            payload_signature;
          })

let create_response node request (payload, payload_signature) =
  Message.
    {
      category = Message.Response;
      sub_category_opt = None;
      id = request.id;
      timestamp = Unix.gettimeofday ();
      sender = !node.address;
      recipients = [request.sender];
      payload;
      payload_signature;
    }

let create_post node (payload, payload_signature) =
  Message.
    {
      category = Message.Post;
      id = -1;
      sub_category_opt = None;
      timestamp = Unix.gettimeofday ();
      sender = !node.address;
      recipients = [];
      payload;
      payload_signature;
    }

let request node request recipient =
  let%lwt message = create_request node recipient request in
  let%lwt () = Networking.send_to node message in
  let condition_var = Lwt_condition.create () in
  Hashtbl.add !node.request_table message.id condition_var;
  Lwt_condition.wait condition_var

let post node message =
  !node.disseminator <- Disseminator.post !node.disseminator message
