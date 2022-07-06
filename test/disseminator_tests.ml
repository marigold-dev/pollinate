open Lwt.Infix
open Commons
open Pollinate
open Pollinate.PNode

module Disseminator_tests = struct
  let node =
    Lwt_main.run
      (let%lwt node_a =
         Node.init ~init_peers:[] Address.{ address = "127.0.0.1"; port = 5000 }
       in
       Lwt.return node_a)

  let queue_insertion_test () =
    let _server = Node.run_server ~msg_handler:Commons.msg_handler node in
    let payload =
      Client.address_of !node
      |> (fun Address.{ port; _ } -> port)
      |> string_of_int
      |> String.to_bytes in
    Client.create_post node payload |> Client.post node;

    Lwt.return (List.length (Node.Testing.broadcast_queue node))

  let queue_removal_test () =
    let _server = Node.run_server ~msg_handler:Commons.msg_handler node in
    let payload =
      Client.address_of !node
      |> (fun Address.{ port; _ } -> port)
      |> string_of_int
      |> String.to_bytes in
    Client.create_post node payload |> Client.post node;

    let%lwt () =
      while%lwt Node.Testing.disseminator_round node <= 10 do
        Lwt_unix.sleep 0.1
      done in
    Lwt.return (List.length (Node.Testing.broadcast_queue node))

  let seen_message_test () =
    let _server = Node.run_server ~msg_handler:Commons.msg_handler node in
    let payload =
      Client.address_of !node
      |> (fun Address.{ port; _ } -> port)
      |> string_of_int
      |> String.to_bytes in
    let message = Client.create_post node payload in
    message |> Client.post node;

    Lwt.return (Node.seen node message)
end

(** Test for dissemination given a specific node. *)
let test_queue_removal _ () =
  Disseminator_tests.queue_removal_test ()
  >|= Alcotest.(check int)
        "Length of broadcast queue is 0 10 rounds after the client posts" 0

let test_queue_insertion _ () =
  Disseminator_tests.queue_insertion_test ()
  >|= Alcotest.(check int)
        "Length of broadcast queue is 1 after the client posts" 1

let test_seen_message _ () =
  Disseminator_tests.seen_message_test ()
  >|= Alcotest.(check bool)
        "A message that's just been posted is seen by the disseminator" true

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Disseminator tests"
       [
         ( "disseminator functions",
           [
             Alcotest_lwt.test_case
               "Messages are removed from queue after 10 rounds" `Quick
               test_queue_removal;
             Alcotest_lwt.test_case
               "Messages are added to the queue when posted" `Quick
               test_queue_insertion;
             Alcotest_lwt.test_case
               "Messages that are posted are immediately seen" `Quick
               test_seen_message;
           ] );
       ]
