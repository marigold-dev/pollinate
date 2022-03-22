(** Types and functions pertaining to peers in a P2P application *)

(** Sum type holding all the available values for peer state *)
type status =
  | Alive
  | Suspicious
  | Faulty
[@@deriving show { with_path = false }, eq]

(** Our representation of a Peer *)
type t = {
  address : Address.t;
  mutable status : status;
  peers : (Address.t, t) Base.Hashtbl.t;
}

(** Obtain the Peer.t from the given list, matching the provided Address.t *)
val retrieve_peer_from_address_opt : t -> Address.t -> t option

(** Constructs a Peer.t from an Address.t *)
val from : Address.t -> t

(** Constructs an Address.t from a Unix.sockaddr *)
val from_socket_address : Unix.sockaddr -> t
