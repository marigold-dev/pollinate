open QCheck2.Gen
open Pollinate
open Messages

module type MTest = sig
  val peer_gen : Peer.t t

  val address_gen : Address.t t

  val peer_print : Peer.t -> string

  val request_gen : Messages.request t
end

module Test : MTest = struct
  let address_gen =
    pair (pure "127.0.0.1") int >|= fun (address, port) ->
    Address.{ address; port }

  let peer_gen =
    let open Peer in
    address_gen >|= fun address ->
    { address; status = Alive; neighbors = Base.Hashtbl.Poly.create () }

  let peer_print peer =
    let open Peer in
    Address.show peer.address

  let request_gen =
    let open Messages in
    let* str = string_printable in
    oneofl [Get; Ping; Insert str]
end
