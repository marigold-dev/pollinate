type state =
  | Alive
  | Suspicious
  | Faulty

(** Our representation of a Peer *)
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

val add_peer : t -> t -> t

val knuth_shuffle : t list -> t list

val pick_random_member : t -> t
