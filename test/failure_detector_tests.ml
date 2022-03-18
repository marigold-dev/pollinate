open Commons
open Lwt.Infix

module Failure_detector_tests = struct
  open Pollinate
  open Failure_detector

  let add_peer_test () =
    let _ = add_peer Commons.peer_a Commons.protocol in
    Lwt.return @@ Base.Hashtbl.length Commons.protocol.peers

  let pick_random_test () =
    let _ = add_peer Commons.peer_a Commons.protocol in
    let peers = pick_random_peer_addresses Commons.protocol.peers 1 in
    Lwt.return @@ List.length peers

  let knuth_shuffle_test () =
    let final_list = knuth_shuffle @@ Base.Hashtbl.keys Commons.protocol.peers in
    Lwt.return @@ List.length final_list
end

let test_add_peer _ () =
  Failure_detector_tests.add_peer_test ()
  >|= Alcotest.(check int)
        "When adding peer to a empty list of know_peers, length is 1" 1

let test_knuth_shuffle _ () =
  Failure_detector_tests.knuth_shuffle_test ()
  >|= Alcotest.(check int) "Knuth_shuffle does not change length of list" 1

let test_pick_random _ () =
  Failure_detector_tests.pick_random_test ()
  >|= Alcotest.(check int)
        "pick_random_peers on a list with one element, length is esual to 1" 1

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Failure_detector tests"
       [
         ( "Failure_detector",
           [
             Alcotest_lwt.test_case "Add peer" `Quick test_add_peer;
             Alcotest_lwt.test_case "Knuth shuffle" `Quick test_knuth_shuffle;
             Alcotest_lwt.test_case "Pick random" `Quick test_pick_random;
           ] );
       ]
