open Bin_prot.Std

type status =
  | Alive
  | Suspicious
  | Faulty

type address = {
  address : string;
  port : int;
}
[@@deriving bin_io]

type t = {
  socket_address : address;
  mutable status : status;
}

let from_sockaddr sockaddr =
  let open Lwt_unix in
  match sockaddr with
  | ADDR_UNIX _ -> failwith "Unix socket addresses not supported"
  | ADDR_INET (inet, port) -> { address = Unix.string_of_inet_addr inet; port }

let to_sockaddr socket_address =
  Lwt_unix.ADDR_INET
    (Unix.inet_addr_of_string socket_address.address, socket_address.port)

let retrieve_peer_from_address (peers : Peer.t list) address =
  let open Peer in
  let address_to_find = address.address in
  let port_to_find = address.port in
  List.find
    (fun p ->
      p.socket_address.address == address_to_find
      && p.socket_address.port == port_to_find)
    peers