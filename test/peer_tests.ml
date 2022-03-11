open Lwt.Infix
open Commons

module Peer_tests = struct
  open Pollinate
  let add_peer_test () =
    let open Commons in
    let peer_b = Peer.add_peer peer_a peer_b in
    let peer = Peer.add_peer peer_c peer_b in
    Lwt.return @@ List.length peer.known_peers

  let knuth_shuffle_test () =
    let open Commons in
    let peer_a = Peer.add_peer peer_b peer_a in
    let peer_a = Peer.add_peer peer_c peer_a in
    let peer_a = Peer.knuth_shuffle peer_a.known_peers in
    Lwt.return @@ List.length peer_a
end

let test_add_peer _ () =
  Peer_tests.add_peer_test ()
  >|= Alcotest.(check int)
        "When adding peer to an empty list of know_peers, length is 1" 2

let test_knuth_shuffle _ () =
  Peer_tests.knuth_shuffle_test ()
  >|= Alcotest.(check int) "Knuth_shuffle does not change length of list" 2

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Peer tests"
       [
         ( "peer",
           [
             Alcotest_lwt.test_case "Add peer" `Quick test_add_peer;
             Alcotest_lwt.test_case "Knuth shuffle" `Quick test_knuth_shuffle;
           ] );
       ]
