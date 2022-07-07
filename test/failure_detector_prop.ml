open QCheck2.Gen
open Pollinate.Peer
open Pollinate
module SUT = Pollinate.PNode.Testing.Failure_detector

let node_a =
  Lwt_main.run (PNode.init Address.{ address = "127.0.0.1"; port = 3002 })

let update_peer =
  QCheck2.Test.make ~count:1000
    ~name:"update_neighbor_status successfully update neighbor status"
    (pair Generators.peer_gen Generators.peer_status_gen)
    (fun (neighbor, neighbor_status) ->
      let _ = add_neighbor (PNode.Client.peer_from !node_a) neighbor in
      let _ = SUT.update_peer_status node_a neighbor neighbor_status in
      neighbor.status = neighbor_status)

let () =
  let failure_detector_prop =
    List.map QCheck_alcotest.to_alcotest [update_peer] in
  Alcotest.run "Failure detector"
    [("failure_detector.ml", failure_detector_prop)]
