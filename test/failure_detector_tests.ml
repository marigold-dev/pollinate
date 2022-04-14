open Commons
open Pollinate.Node
open Lwt.Infix

module SUT = Pollinate.Node.Failure_detector

let node_a =
  Lwt_main.run
    (Node.init ~router:Commons.router ~state:["test1"]
       ~msg_handler:Commons.msg_handler ("127.0.0.1", 3003))
let node_b =
  Lwt_main.run
    (Node.init ~router:Commons.router ~state:["test1"]
       ~msg_handler:Commons.msg_handler ("127.0.0.1", 3004))

let peer_b = Client.peer_from !node_b

let suspicion_detection () =
  let open Common.Peer in
  let open Client in
  let _ = add_peer !node_a peer_b in
  let _ = Pollinate.Node.Client.peer_from !node_a in
  let _ = SUT.update_peer_status node_a peer_b Suspicious in
  (* Need to wait for the timeout to be reached An other way to do, would be to change the `last_suspicious_status` of the peer *)
  let%lwt _ = Lwt_unix.sleep 9.01 in
  let%lwt _ = SUT.suspicious_detection node_a in
  Lwt.return (Base.Hashtbl.length !node_a.peers = 0)

let suspicion_detection_nothing_on_alive () =
  let open Common.Peer in
  let _ = add_neighbor (Pollinate.Node.Client.peer_from !node_a) peer_b in
  let _ = SUT.update_peer_status node_a peer_b Alive in
  let%lwt _ = SUT.suspicious_detection node_a in
  Lwt.return (Base.Hashtbl.length !node_a.peers = 1)

let test_suspicion_detection _ () =
  suspicion_detection () >|= Alcotest.(check bool) "" true

let test_suspicion_detection_nothing_on_alive _ () =
  suspicion_detection_nothing_on_alive () >|= Alcotest.(check bool) "" true

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Suspicion detector"
       [
         ( "failure_detector.ml",
           [
             Alcotest_lwt.test_case "Remove Suspicious peer" `Quick
               test_suspicion_detection;
             Alcotest_lwt.test_case "Do nothing on Alive peer" `Quick
               test_suspicion_detection_nothing_on_alive;
           ] );
       ]
