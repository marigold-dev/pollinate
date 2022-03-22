(** Types and functions to deal with peer within the P2P application *)
type status =
  | Alive
  | Suspicious
  | Faulty
[@@deriving show { with_path = false }, eq]

type t = {
  address : Address.t;
  mutable status : status;
  peers : (Address.t, t) Base.Hashtbl.t;
}

let retrieve_peer_from_address_opt peer address =
  Base.Hashtbl.find peer.peers address

let from (address : Address.t) =
  {
    address;
    status = Alive;
    peers = Base.Hashtbl.create ~growth_allowed:true ~size:0 (module Address);
  }

let from_socket_address (address : Unix.sockaddr) =
  from @@ Address.from_sockaddr address
