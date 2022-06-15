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

let create_request node recipient payload =
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
          })

let create_response node request payload =
  Message.
    {
      category = Message.Response;
      sub_category_opt = None;
      id = request.id;
      timestamp = Unix.gettimeofday ();
      sender = !node.address;
      recipients = [request.sender];
      payload;
    }

let create_post node payload =
  Message.
    {
      category = Message.Post;
      id = -1;
      sub_category_opt = None;
      timestamp = Unix.gettimeofday ();
      sender = !node.address;
      recipients = [];
      payload;
    }

let request node request recipient =
  let%lwt message = create_request node recipient request in
  let%lwt () = Networking.send_to node message in
  let condition_var = Lwt_condition.create () in
  Hashtbl.add !node.request_table message.id condition_var;
  Lwt_condition.wait condition_var

let post node message =
  !node.disseminator <- Disseminator.post !node.disseminator message
