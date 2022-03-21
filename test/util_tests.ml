open Pollinate.Util

module Tests = struct
  open Bin_prot.Std

  let encode_decode s =
    s
    |> Encoding.pack (bin_writer_list bin_writer_string)
    |> Encoding.unpack (bin_read_list bin_read_string)
    |> ( = ) s
end

let test_encode_decode =
  QCheck.Test.make ~count:1000
    ~name:"Encoding then decoding payload results in same payload"
    QCheck.(list string)
    Tests.encode_decode
  |> QCheck_alcotest.to_alcotest

let () = Alcotest.run "Utility Tests" [("Encoding", [test_encode_decode])]
