type t = {
  address : string;
  port : int;
}
(** Our representation of a Peer *)

val from_sockaddr : Unix.sockaddr -> t
(** Obtain a Pollinate.Peer from a Unix.sockaddr *)

val to_sockaddr : t -> Unix.sockaddr
(** Obtain a Unix.sockaddr from a Pollinate.Peer *)