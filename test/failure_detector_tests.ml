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
  let _ = add_neighbor (Pollinate.Node.Client.peer_from !node_a) peer_b in
  let _ = SUT.update_peer_status node_a peer_b Suspicious in
  let%lwt _ = SUT.suspicious_detection node_a in
  Lwt.return (Base.Hashtbl.length !node_a.peers = 0)

let test_suspicion_detection _ () =
  suspicion_detection () >|= Alcotest.(check bool) "test2 and test1" true

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Suspicion detecter"
       [
         ( "failure_detector.ml",
           [
             Alcotest_lwt.test_case "Remove suspicious peer" `Quick
               test_suspicion_detection;
           ] );
       ]
