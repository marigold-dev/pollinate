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

(** Add the given peer to the existing peer *)
val add_peer : t -> t -> t

(** Basic Knuth shuffle for the know_peers list*)
val knuth_shuffle : t list -> t list

(** Randomly pick one know_peer from the list of the given peer*)
val pick_random_member : t -> t
