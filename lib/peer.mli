(** Types and functions pertaining to peers in a P2P application *)

(** Sum type holding all the available values for peer state *)
type status =
  | Alive
  | Suspicious
  | Faulty

(** Our representation of a Peer
  See Client.peer_from to construct one *)
type t = {
  address : Address.t;
  mutable status : status;
}

(** Obtain the Peer.t from the given list, matching the provided Address.t *)
val retrieve_peer_from_address_opt :
  (Address.t, t) Base.Hashtbl.t -> Address.t -> t option

(** Constructs a Peer.t from an Address.t *)
val peer_from : Address.t -> t

val peer_from_socket_address : Unix.sockaddr -> t
