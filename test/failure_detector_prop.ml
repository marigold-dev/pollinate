open Generator.Test
open QCheck2.Gen
open Pollinate.Peer
open Commons

module SUT = Pollinate.Node.Failure_detector

let knuth_shuffle_size =
  QCheck2.Test.make ~count:1000
    ~name:"Knuth_shuffle does not change the size of the list"
    (QCheck2.Gen.list peer_gen) (fun peers ->
      List.length (SUT.knuth_shuffle peers) == List.length peers)

let update_peer =
   QCheck2.Test.make ~count:1000
     ~name:"update_neighbor_status successfully update neighbor status"
     (pair peer_gen peer_status_gen)
     (fun (neighbor, neighbor_status) ->
       let _ = add_neighbor (Pollinate.Node.Client.peer_from !Commons.node_a) neighbor in
       let _ = SUT.update_peer_status Commons.node_a neighbor neighbor_status in
       neighbor.status = neighbor_status)

let pick_random_neighbors =
  QCheck2.Test.make ~count:1000
    ~name:
      "pick_random_neighbors on a peer with a single neighbor, returns this \
       neighbors" (pair peer_gen peer_gen) (fun (peer, neighbor) ->
      let _ = add_neighbor peer neighbor in
      let random_neighbor =
        List.hd @@ SUT.pick_random_neighbors peer.neighbors 1 in
      random_neighbor == neighbor.address)

let () =
  let failure_detector_prop =
    List.map QCheck_alcotest.to_alcotest
      [knuth_shuffle_size; update_peer; pick_random_neighbors] in
  Alcotest.run "Failure detector"
    [("failure_detector.ml", failure_detector_prop)]
