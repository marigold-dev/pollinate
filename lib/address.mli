type t [@@deriving bin_io, eq]

(** Obtain an Address.t from a Unix.sockaddr *)
val from_sockaddr : Unix.sockaddr -> t

(** Obtain a Unix.sockaddr from an Address.t *)
val to_sockaddr : t -> Unix.sockaddr

(** Get the address as string of the provided address *)
val address_of : t -> string

(** Get the port as int of the provided address *)
val port_of : t -> int

(** Create a Address.t from address as string and port as int *)
val create : string -> int -> t
