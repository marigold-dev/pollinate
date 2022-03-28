open QCheck2.Gen
open Pollinate
open Commons

module type MTest = sig
  val peer_gen : Peer.t t

  val address_gen : Address.t t
  
  val peer_print : Peer.t -> string

  val request_gen : Commons.request t

  val insert_gen : Commons.request t

end

module Test : MTest = struct

  let address_gen =
    pair (pure "localhost") (int)
    >|= fun (address, port) -> Address.{address; port}

  let peer_gen =
    let open Peer in
    address_gen >|= fun address ->
    {address = address; status = Alive; neighbors = Base.Hashtbl.Poly.create ()}

  let peer_print peer =
    let open Peer in
    Address.show peer.address
  
  let insert_gen =
    string_printable >|= fun str -> Commons.Insert str

  let request_gen =
    insert_gen >|= fun insert -> oneofl Commons.[Get;Ping;insert]
end
