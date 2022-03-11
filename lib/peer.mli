(** Types and functions pertaining to peers in a P2P application *)

(** Sum type holding all the available values for peer state *)
type state =
  | Alive
  | Suspicious
  | Faulty

(** Our representation of a Peer
  See Client.peer_from to construct one *)
type t = {
  address : string;
  port : int;
  known_peers : t list;
  state : state;
}

(** Obtain a Pollinate.Peer from a Unix.sockaddr *)
val from_sockaddr : Unix.sockaddr -> t

(** Obtain a Unix.sockaddr from a Pollinate.Peer *)
val to_sockaddr : t -> Unix.sockaddr

(** Each peer have a list of known peers
  this function add the provided peer to the previous list
  of the given peer *)
val add_peer : t -> t -> t

(** Following SWIM protocol, the list mut be randomized after adding a peer *)
val knuth_shuffle : t list -> t list

(** Following SWIM protocol,
  the pick of a peer to which send the Ping message must be randomly chosen*)
val pick_random_member : t -> t
