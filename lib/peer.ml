type state =
  | Alive
  | Suspicious
  | Faulty

type t = {
  address : string;
  port : int;
  known_peers : t list;
  state : state;
}

let from_sockaddr sockaddr =
  let open Lwt_unix in
  match sockaddr with
  | ADDR_UNIX _ -> failwith "Unix socket addresses not supported"
  | ADDR_INET (inet, port) ->
    {
      address = Unix.string_of_inet_addr inet;
      port;
      known_peers = [];
      state = Alive;
    }

let to_sockaddr peer =
  Lwt_unix.ADDR_INET (Unix.inet_addr_of_string peer.address, peer.port)
