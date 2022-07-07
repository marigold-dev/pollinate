open Util
open Common
open Types

(** Signals a waiting request with its corresponding response
   if it exists. Otherwise returns None. *)
let handle_response node res =
  let open Message in
  match Hashtbl.find_opt !node.request_table res.id with
  | Some waiting_request -> Lwt_condition.signal waiting_request res
  | None -> ()

let handle_ack node msg =
  if msg.Message.request_ack then
    let ack_msg = Client.create_ack node msg in
    Networking.send_to node ack_msg
  else
    Lwt.return ()

(* Preprocess a message, log some information about it, then handle it
   based on its category. The "rules" are as follows:

   Response: send the message to a "handle_response" function which wakes
   up a sleeping request function with the response it was waiting for.

   Request: run the message handler on the incoming request and, if the message
   handler returned a response, send it to the requester.

   Failure_detection: send the message to the Failure_detector.handle_message function

   Post: check if the post has been seen (or if its outdated). If not, then handle the post with
   the message handler, then disseminate it to this node's peers by reposting it.

   Otherwise, we just apply the message handler and that's it.
*)
let process_message node preprocessor
    (msg_handler : Message.t -> Message.payload option) =
  let open Message in
  let%lwt message = Networking.recv_next node in
  let message = preprocessor message in
  let _ = handle_ack node message in
  (* let%lwt () =
     log node
       (Printf.sprintf "Processing message %s from %d...\n"
          (Message.hash_of message) message.sender.port) in *)
  let%lwt () =
    match message.category with
    | Response -> Lwt.return (handle_response node message)
    | Request -> (
      (* let%lwt () =
         log node
           (Printf.sprintf "%s:%d : Processing request from %s:%d\n"
              !node.address.address !node.address.port message.sender.address
              message.sender.port) in *)
      match msg_handler message with
      | Some msg ->
        (* let _ = Printf.sprintf "I am inside msg_handler, found payload\n%!" in *)
        Client.create_response node message ?payload_signature:msg.signature
          msg.data
        |> Networking.send_to node
      | None ->
        failwith "received request without payload nor payload_signature")
    | Acknowledgment ->
      let msg_hash = Bytes.to_string message.payload.data in
      let new_addrs =
        match Hashtbl.find_opt !node.acknowledgments msg_hash with
        | Some addrs -> AddressSet.add message.sender addrs
        | None -> AddressSet.add message.sender AddressSet.empty in
      Hashtbl.add !node.acknowledgments msg_hash new_addrs;
      Lwt.return ()
    | Failure_detection -> Failure_detector.handle_message node message
    | Post ->
      if not (Disseminator.seen !node.disseminator message) then (
        (* let%lwt () =
           log node
             (Printf.sprintf "%s:%d : Processing post %s from %s:%d\n"
                !node.address.address !node.address.port
                (Message.hash_of message) message.sender.address
                message.sender.port) in *)
        let _ = msg_handler message in
        (* let%lwt () = log node "Adding message to broadcast queue\n" in *)
        Client.post node message;
        Lwt.return ())
      else
        (* log node
           (Printf.sprintf "Got post %s from %s:%d but saw it already\n"
              (Message.hash_of message) message.sender.address
              message.sender.port) *)
        Lwt.return ()
    | _ ->
      let _ = msg_handler message in
      Lwt.return () in
  Lwt.return ()

(** Log some initial information at the beginning of a server iteration.
    See comments for descriptions regarding what is actually being logged. *)
let _print_logs node =
  (* Check that the server is in fact running *)
  let%lwt () = log node "Running server\n" in
  (* Check which posts the node has seen so far *)
  let%lwt () =
    log node
      (Printf.sprintf "Seen: %s\n"
         (Disseminator.get_seen_messages !node.disseminator
         |> String.concat " ; ")) in
  (* Check who the current peers of the node are *)
  let%lwt () =
    !node.peers
    |> Base.Hashtbl.keys
    |> List.map (fun Address.{ port; _ } -> string_of_int port)
    |> String.concat " ; "
    |> Printf.sprintf "Peers: %s\n"
    |> log node in
  (* Check which posts are currently being disseminated by the node *)
  if List.length (Disseminator.broadcast_queue !node.disseminator) > 0 then
    let%lwt () =
      !node.disseminator
      |> Disseminator.broadcast_queue
      |> List.map Message.hash_of
      |> String.concat " "
      |> Printf.sprintf "Broadcast Queue: %s\n"
      |> log node in
    Lwt.return ()
  else
    Lwt.return ()

(* Sever procedure:
   0. Log pertinent information about the current node.
   1. Start a new thread for handling any incoming message.
   2. Run the failure detector.
   3. Run the disseminator, this includes actually sending messages to be
      disseminated across the network.
   4. Wait 0.001 seconds before restarting the procedure. *)
let rec run node preprocessor
    (msg_handler : Message.t -> Message.payload option) =
  (* Step 0 *)
  (* let%lwt () = print_logs node in *)
  (* Step 1 *)
  let _ = process_message node preprocessor msg_handler in
  (* Step 2 *)
  let%lwt () = Failure_detector.failure_detection node in
  (* Step 3 *)
  let%lwt () = Networking.disseminate node in
  (* Step 4 *)
  let%lwt () = Lwt_unix.sleep 0.001 in
  run node preprocessor msg_handler
