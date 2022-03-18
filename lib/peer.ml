type status =
  | Alive
  | Suspicious
  | Faulty

type t = {
  address : Address.t;
  mutable status : status;
}

let retrieve_peer_from_address_opt (peers : (Address.t, t) Base.Hashtbl.t)
    address =
  Base.Hashtbl.find peers address

let peer_from (address : Address.t) = { address; status = Alive }

let peer_from_socket_address (address : Unix.sockaddr) =
  peer_from @@ Address.from_sockaddr address
