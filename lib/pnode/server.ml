open Common.Util
open Types

let route node router msg =
  let open Message in
  let msg = router msg in
  Inbox.push !node.inbox msg.category msg

(** Signals a waiting request with its corresponding response
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
     node's state
   5. Send the encoded response from the message handler to the requester *)
let run node router (msg_handler : Message.t -> bytes * bytes option) =
  let rec server () =
    let%lwt message = Client.recv_next node in
    let%lwt () = route node router message in

    let%lwt () =
      match%lwt Inbox.next !node.inbox Message.Failure_detection with
      | Some message -> Failure_detector.handle_message node message
      | None -> Lwt.return () in

    let%lwt () = Failure_detector.suspicion_detection node in
    let%lwt () = Failure_detector.failure_detection node in

    let%lwt next_response = Inbox.next !node.inbox Message.Response in
    let _ = handle_response !node.request_table next_response in

    let%lwt request = Inbox.next !node.inbox Message.Request in
    let%lwt () =
      match request with
      | Some request ->
        let res : bytes * bytes option = msg_handler request in
        let response = Client.create_response node request res in
        let%lwt () = Client.send_to node response in
        Lwt.return ()
      | None -> Lwt.return () in

    server () in
  Lwt.async server
