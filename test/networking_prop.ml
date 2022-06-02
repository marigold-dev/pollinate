open QCheck2.Gen
open Pollinate.Peer
open Pollinate

module SUT = Pollinate.PNode.Testing.Networking

let node_a =
  Lwt_main.run (PNode.init Address.{ address = "127.0.0.1"; port = 2002 })

let knuth_shuffle_size =
  QCheck2.Test.make ~count:1000
    ~name:"Knuth_shuffle does not change the size of the list"
    (QCheck2.Gen.list Generators.peer_gen) (fun peers ->
      List.length (SUT.Testing.knuth_shuffle peers) == List.length peers)

let pick_random_neighbors =
  QCheck2.Test.make ~count:1000
    ~name:
      "pick_random_neighbors on a peer with a single neighbor, returns this \
       neighbors" (pair Generators.peer_gen Generators.peer_gen)
    (fun (peer, neighbor) ->
      let _ = add_neighbor peer neighbor in
      let random_neighbor =
        List.hd @@ SUT.pick_random_neighbors peer.neighbors 1 in
      random_neighbor == neighbor.address)

let () =
  let networking_prop =
    List.map QCheck_alcotest.to_alcotest
      [knuth_shuffle_size; pick_random_neighbors] in
  Alcotest.run "Networking" [("networking.ml", networking_prop)]
