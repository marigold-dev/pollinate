open Bin_prot.Std
open Ppx_compare_lib.Builtin
open Ppx_hash_lib.Std
open Hash.Builtin
open Ppx_sexp_conv_lib.Conv

type t = {
  address : string;
  port : int;
}
[@@deriving bin_io, eq, compare, hash, sexp]

let create address port = { address; port }

let address_of { address; _ } = address

let port_of { port; _ } = port

let from_sockaddr sockaddr =
  let open Lwt_unix in
  match sockaddr with
  | ADDR_UNIX _ -> failwith "Unix socket addresses are not supported"
  | ADDR_INET (inet, port) -> { address = Unix.string_of_inet_addr inet; port }

let to_sockaddr socket_address =
  Lwt_unix.ADDR_INET
    (Unix.inet_addr_of_string socket_address.address, socket_address.port)
