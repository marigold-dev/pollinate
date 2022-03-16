(** Types and functions pertaining to peers in a P2P application *)

(** Sum type holding all the available values for peer state *)
type status =
  | Alive
  | Suspicious
  | Faulty

(** Our representation of a Peer
  See Client.peer_from to construct one *)
type t = {
  socket_address : Address.t;
  mutable status : status;
}

val retrieve_peer_from_address : t list -> Address.t -> t