type status =
  | Alive
  | Suspicious
  | Faulty

type t = {
  socket_address : Address.t;
  mutable status : status;
}

let retrieve_peer_from_address (peers : t list) (address : Address.t) =
  List.find
    (fun p ->
      p.socket_address = address)
    peers
