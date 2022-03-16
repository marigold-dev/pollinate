(** Types and functions pertaining to peers in a P2P application *)

(** Sum type holding all the available values for peer state *)
type status =
  | Alive
  | Suspicious
  | Faulty

(** Wrapper for socket address *)
type address = {
  address : string;
  port : int;
}
[@@deriving bin_io]

(** Our representation of a Peer
  See Client.peer_from to construct one *)
type t = {
  socket_address : address;
  mutable status : status;
}

(** Obtain a Pollinate.Peer from a Unix.sockaddr *)
val from_sockaddr : Unix.sockaddr -> address

(** Obtain a Unix.sockaddr from a Pollinate.Peer *)
val to_sockaddr : address -> Unix.sockaddr

val retrieve_peer_from_address : t list -> address -> t