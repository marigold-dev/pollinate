open Lwt.Infix
open Commons
open Pollinate
open Pollinate.PNode

module Disseminator_tests = struct
  let node =
    Lwt_main.run
      (let%lwt node_a =
         PNode.init ~init_peers:[]
           Address.{ address = "127.0.0.1"; port = 5000 } in
       Lwt.return node_a)

  let queue_insertion_test () =
    let _server = PNode.run_server ~msg_handler:Commons.msg_handler node in
    let payload =
      Client.address_of !node
      |> (fun Address.{ port; _ } -> port)
      |> string_of_int
      |> String.to_bytes in
    Client.create_post node (payload, None) |> Client.post node;

    Lwt.return (List.length (PNode.Testing.broadcast_queue node))

  let queue_removal_test () =
    let _server = PNode.run_server ~msg_handler:Commons.msg_handler node in
    let payload =
      Client.address_of !node
      |> (fun Address.{ port; _ } -> port)
      |> string_of_int
      |> String.to_bytes in
    Client.create_post node (payload, None) |> Client.post node;

    let%lwt () =
      while%lwt PNode.Testing.disseminator_round node <= 10 do
        Lwt_unix.sleep 0.1
      done in
    Lwt.return (List.length (PNode.Testing.broadcast_queue node))

  let seen_message_test () =
    let _server = PNode.run_server ~msg_handler:Commons.msg_handler node in
    let payload =
      Client.address_of !node
      |> (fun Address.{ port; _ } -> port)
      |> string_of_int
      |> String.to_bytes in
    let message = Client.create_post node (payload, None) in
    message |> Client.post node;

    Lwt.return (PNode.seen node message)
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
               test_seen_message
             (* Alcotest_lwt.test_case "Dissemination from A" `Quick
                (test_disseminate_from Gossip_tests.node_a); *)
             (* Alcotest_lwt.test_case "Dissemination from B" `Quick
                  (test_disseminate_from Gossip_tests.node_b);
                Alcotest_lwt.test_case "Dissemination from C" `Quick
                  (test_disseminate_from Gossip_tests.node_c);
                Alcotest_lwt.test_case "Dissemination from D" `Quick
                  (test_disseminate_from Gossip_tests.node_d); *)
             (* Alcotest_lwt.test_case "Dissemination from E" `Quick
                (test_disseminate_from Gossip_tests.node_e); *)
             (* Alcotest_lwt.test_case "Dissemination from F" `Quick
                (test_disseminate_from Gossip_tests.node_f); *)
             (* Alcotest_lwt.test_case "Dissemination from G" `Quick
                (test_disseminate_from Gossip_tests.node_g); *)
             (* Alcotest_lwt.test_case "Dissemination from H" `Quick
                (test_disseminate_from Gossip_tests.node_h); *)
             (* Alcotest_lwt.test_case "Dissemination from I" `Quick
                (test_disseminate_from Gossip_tests.node_i); *)
             (* Alcotest_lwt.test_case "Dissemination from J" `Quick
                (test_disseminate_from Gossip_tests.node_j); ;*);
           ] );
       ]
