(** An address is a [string] representation of an IP address 
    and an [int] representation of a port. *)

(** {1 Type} *)

type t = {
  address : string;
  port : int;
}
[@@deriving bin_io, eq, compare, hash, sexp, show { with_path = false }]

(** {1 API} *)

val create : string -> int -> t
(** Create an [Address.t] from [address] as {i string} and [port] as {i int} *)

val from_sockaddr : Unix.sockaddr -> t
(** Obtain an [Address.t] from a [Unix.sockaddr] *)

val to_sockaddr : t -> Unix.sockaddr
(** Obtain a [Unix.sockaddr] from an [Address.t] *)
