type t [@@deriving bin_io, eq]

(** Obtain a Pollinate.Peer from a Unix.sockaddr *)
val from_sockaddr : Unix.sockaddr -> t

(** Obtain a Unix.sockaddr from a Pollinate.Peer *)
val to_sockaddr : t -> Unix.sockaddr

val address_of : t -> string

val port_of : t -> int

val create_address : string -> int -> t