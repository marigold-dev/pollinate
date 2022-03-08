type t =
  { address: string
  ; port: int
  }

let from_sockaddr sockaddr =
  let open Lwt_unix in
  match sockaddr with
  | ADDR_UNIX _ -> failwith "Unix socket addresses not supported"
  | ADDR_INET (inet, port) -> { address = Unix.string_of_inet_addr inet; port }

let to_sockaddr peer =
  Lwt_unix.ADDR_INET (Unix.inet_addr_of_string peer.address, peer.port)