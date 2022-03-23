type t = {
  address : string;
  port : int;
}
[@@deriving bin_io, eq, compare, hash, sexp, show { with_path = false }]

(** Create a Address.t from address as string and port as int *)
val create : string -> int -> t

(** Obtain an Address.t from a Unix.sockaddr *)
val from_sockaddr : Unix.sockaddr -> t

(** Obtain a Unix.sockaddr from an Address.t *)
val to_sockaddr : t -> Unix.sockaddr
