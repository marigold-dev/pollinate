type status =
  | Alive
  | Suspicious
  | Faulty

type t = {
  address : Address.t;
  mutable status : status;
  mutable peers : (Address.t, t) Base.Hashtbl.t;
}

let retrieve_peer_from_address_opt (peers : (Address.t, t) Base.Hashtbl.t)
    address =
  Base.Hashtbl.find peers address

let peer_from (address : Address.t) =
  {
    address;
    status = Alive;
    peers = Base.Hashtbl.create ~growth_allowed:true ~size:0 (module Address);
  }

let peer_from_socket_address (address : Unix.sockaddr) =
  peer_from @@ Address.from_sockaddr address
