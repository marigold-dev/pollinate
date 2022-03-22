open Commons
open Lwt.Infix

module Failure_detector_tests = struct
  open Pollinate
  open Failure_detector

  let add_peer_test () =
    let _ = add_peer Commons.peer_b Commons.peer_a in
    Lwt.return @@ Base.Hashtbl.length Commons.peer_b.peers

  let pick_random_test () =
    let peers = pick_random_peer_addresses Commons.peer_b.peers 1 in
    Lwt.return @@ List.length peers

  let knuth_shuffle_test () =
    let final_list = knuth_shuffle @@ Base.Hashtbl.keys Commons.peer_b.peers in
    Lwt.return @@ List.length final_list

  let update_peer_test () =
    let _ = update_peer Commons.peer_b Commons.peer_a Suspicious in
    Lwt.return @@ Peer.show_status Commons.peer_a.status
end

let test_add_peer _ () =
  Failure_detector_tests.add_peer_test ()
  >|= Alcotest.(check int)
        "When adding peer to a empty list of know_peers, length is equal to 1" 1

let test_knuth_shuffle _ () =
  Failure_detector_tests.knuth_shuffle_test ()
  >|= Alcotest.(check int) "Knuth_shuffle does not change length of list" 1

let test_pick_random _ () =
  Failure_detector_tests.pick_random_test ()
  >|= Alcotest.(check int)
        "pick_random_peers on a list with one element, length is equal to 1" 1
let test_update_peer _ () =
  Failure_detector_tests.update_peer_test ()
  >|= Alcotest.(check string)
        "pick_random_peers on a list with one element, length is equal to 1"
        "Suspicious"

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Failure_detector tests"
       [
         ( "Failure_detector",
           [
             Alcotest_lwt.test_case "Add peer" `Quick test_add_peer;
             Alcotest_lwt.test_case "Knuth shuffle" `Quick test_knuth_shuffle;
             Alcotest_lwt.test_case "Pick random" `Quick test_pick_random;
             Alcotest_lwt.test_case "Update status" `Quick test_update_peer;
           ] );
       ]
