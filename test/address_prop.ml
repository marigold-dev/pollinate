open QCheck2.Gen
open Generator.Test

module SUT = Pollinate.Address

let create =
  QCheck2.Test.make ~count:1000
    ~name:"create from string and port is successful" (pair string int)
    (fun (address, port) ->
      let addr = SUT.create address port in
      addr.port == port && addr.address == address)

let from_sockaddr =
  QCheck2.Test.make ~count:1000
    ~name:"from_sockaddr from any sockaddress is successful" sockaddress_gen
    (fun sockaddress ->
      let addr = SUT.from_sockaddr sockaddress in
      match sockaddress with
      | Unix.ADDR_INET (address, port) ->
        addr.port = port && addr.address = Unix.string_of_inet_addr address
      | _ -> failwith "Unreachable: from_sockaddr")

let to_sockaddr =
  QCheck2.Test.make ~count:1000
    ~name:"to_sockaddr from any address is successful" address_gen
    (fun address ->
      let addr = SUT.to_sockaddr address in
      match addr with
      | Unix.ADDR_INET (address_inet, port) ->
        Unix.string_of_inet_addr address_inet = address.address
        && port = address.port
      | _ -> failwith "Unreachable: from_sockaddr")

let () =
  let failure_detector_prop =
    List.map QCheck_alcotest.to_alcotest [create; from_sockaddr; to_sockaddr]
  in
  Alcotest.run "Address tests" [("address.ml", failure_detector_prop)]
