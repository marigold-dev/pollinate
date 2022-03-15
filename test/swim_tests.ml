open Commons
open Lwt.Infix

module Swim_tests = struct
  open Pollinate
  let add_peer_test () =
    let _ = Swim.add_peer Commons.peer_a Commons.protocol in
    Lwt.return @@ List.length Commons.protocol.peers

  let pick_random_test () =
    let _ = Swim.add_peer Commons.peer_a Commons.protocol in
    let peer = Swim.pick_random_peer Commons.protocol in
    Lwt.return @@ peer.socket_address.port

  let knuth_shuffle_test () =
    let final_list = Swim.knuth_shuffle Commons.protocol.peers in
    Lwt.return @@ List.length final_list
end

let test_add_peer _ () =
  Swim_tests.add_peer_test ()
  >|= Alcotest.(check int)
        "When adding peer to a empty list of know_peers, length is 1" 1

let test_knuth_shuffle _ () =
  Swim_tests.knuth_shuffle_test ()
  >|= Alcotest.(check int) "Knuth_shuffle does not change length of list" 1

let test_pick_random _ () =
  Swim_tests.pick_random_test ()
  >|= Alcotest.(check int)
        "Pick_random on a list with one element, returns this element" 3000

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "SWIM tests"
       [
         ( "SWIM",
           [
             Alcotest_lwt.test_case "Add peer" `Quick test_add_peer;
             Alcotest_lwt.test_case "Knuth shuffle" `Quick test_knuth_shuffle;
             Alcotest_lwt.test_case "Pick random" `Quick test_pick_random;
           ] );
       ]
