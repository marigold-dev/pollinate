(* open Generator.Test
   open Pollinate
   open QCheck2.Gen

   let knuth_shuffle_size =
     QCheck2.Test.make ~count:1000
       ~name:"Knuth_shuffle does not change the size of the list"
       (QCheck2.Gen.list peer_gen) (fun peers ->
         List.length (Failure_detector.knuth_shuffle peers) == List.length peers)

   let update_peer =
     QCheck2.Test.make ~count:1000
       ~name:"update_neighbor_status successfully update neighbor status"
       (triple peer_gen peer_gen peer_status_gen)
       (fun (peer, neighbor, neighbor_status) ->
         let _ = Peer.add_neighbor peer neighbor in
         let () =
           Failure_detector.update_neighbor_status peer neighbor neighbor_status
         in
         neighbor.status = neighbor_status)

   let pick_random_neighbors =
     QCheck2.Test.make ~count:1000
       ~name:
         "pick_random_neighbors on a peer with a single neighbor, returns this \
          neighbors" (pair peer_gen peer_gen) (fun (peer, neighbor) ->
         let _ = Peer.add_neighbor peer neighbor in
         let random_neighbor =
           List.hd @@ Failure_detector.pick_random_neighbors peer.neighbors 1 in
         random_neighbor == neighbor.address)

   let () =
     let failure_detector_prop =
       List.map QCheck_alcotest.to_alcotest [knuth_shuffle_size; update_peer] in
     Alcotest.run "Failure detector"
       [("failure_detector.ml", failure_detector_prop)] *)
