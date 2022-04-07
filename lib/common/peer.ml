type status =
  | Alive
  | Suspicious
  | Faulty
[@@deriving show { with_path = false }, eq]

type t = {
  address : Address.t;
  mutable status : status;
  mutable last_suspicious_status : Unix.tm option;
  neighbors : (Address.t, t) Base.Hashtbl.t;
}

let add_neighbor peer peer_to_add =
  Base.Hashtbl.add peer.neighbors ~key:peer_to_add.address ~data:peer_to_add

let add_neighbors peer peers_to_add = List.map (add_neighbor peer) peers_to_add

let get_neighbor peer address = Base.Hashtbl.find peer.neighbors address

let from address =
  {
    address;
    status = Alive;
    last_suspicious_status = None;
    neighbors =
      Base.Hashtbl.create ~growth_allowed:true ~size:0 (module Address);
  }

let from_socket_address (address : Unix.sockaddr) =
  from @@ Address.from_sockaddr address
