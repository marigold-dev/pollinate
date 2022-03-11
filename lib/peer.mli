type state =
  | Alive
  | Suspicious
  | Faulty

type t = {
  address : string;
  port : int;
  known_peers : t list;
  state : state;
}
(** Our representation of a Peer *)

val from_sockaddr : Unix.sockaddr -> t
(** Obtain a Pollinate.Peer from a Unix.sockaddr *)

val to_sockaddr : t -> Unix.sockaddr
(** Obtain a Unix.sockaddr from a Pollinate.Peer *)

val add_peer : t -> t -> t

val knuth_shuffle : t list -> t list

val pick_random_member : t -> t
