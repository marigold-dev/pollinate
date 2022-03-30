open Generator.Test
open Pollinate

let knuth_shuffle_size =
  QCheck2.Test.make ~count:1000
    ~name:"Knuth_shuffle does not change the size of the list"
    (QCheck2.Gen.list peer_gen) (fun peers ->
      List.length (Failure_detector.knuth_shuffle peers) == List.length peers)

let () =
  let knuth_shuffle_prop =
    List.map QCheck_alcotest.to_alcotest [knuth_shuffle_size] in
  Alcotest.run "my test" [("suite", knuth_shuffle_prop)]
