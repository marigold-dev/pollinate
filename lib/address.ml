open Bin_prot.Std

type t = {
  address : string;
  port : int;
}
[@@deriving bin_io, eq]

let address_of address =
  match address with
  | t -> t.address

let port_of address =
  match address with
  | t -> t.port

let create address port = { address; port }

let from_sockaddr sockaddr =
  let open Lwt_unix in
  match sockaddr with
  | ADDR_UNIX _ -> failwith "Unix socket addresses are not supported"
  | ADDR_INET (inet, port) -> { address = Unix.string_of_inet_addr inet; port }

let to_sockaddr socket_address =
  Lwt_unix.ADDR_INET
    (Unix.inet_addr_of_string socket_address.address, socket_address.port)
