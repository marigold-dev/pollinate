open Generator.Test
open Pollinate.Util
open Commons

let pack_unpack =
  QCheck2.Test.make 
  ~count:1000
  ~name:"unpack . pack returns the original value"
  request_gen
  (fun random_request -> 
    let open Commons in 
    random_request == 
    Encoding.unpack bin_read_request @@ Encoding.pack bin_writer_request random_request)

let () =
  let pack_unpack_prop = List.map QCheck_alcotest.to_alcotest [pack_unpack]
  in
  Alcotest.run "my test" [
    "suite", pack_unpack_prop
  ]
