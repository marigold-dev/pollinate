open Messages

module SUT = Pollinate.Util.Encoding

let pack_unpack =
  QCheck2.Test.make ~count:1000 ~name:"unpack . pack returns the original value"
    Generators.request_gen (fun random_request ->
      let open Messages in
      random_request
      = SUT.unpack bin_read_request
        @@ SUT.pack bin_writer_request random_request)

let () =
  let pack_unpack_prop = List.map QCheck_alcotest.to_alcotest [pack_unpack] in
  Alcotest.run "my test" [("suite", pack_unpack_prop)]
