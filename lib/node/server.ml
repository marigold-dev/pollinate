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
let process_message node preprocessor msg_handler =
  let open Message in
  let%lwt message = Networking.recv_next node in
  let message = preprocessor message in
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
      | Some response ->
        response
        |> Client.create_response node message
        |> Networking.send_to node
      | None -> Lwt.return ())
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

let run_background_processes node ~period =
  let rec run_recursively () =
    let%lwt () = Failure_detector.failure_detection node in
    let%lwt () = Networking.disseminate node in
    let%lwt () = Lwt_unix.sleep period in
    run_recursively () in
  Lwt.async run_recursively

let rec run node preprocessor msg_handler =
  let%lwt () = process_message node preprocessor msg_handler in
  run node preprocessor msg_handler
