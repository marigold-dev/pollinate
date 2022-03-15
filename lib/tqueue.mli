(** Thread-safe queues with the same exact interface
as OCaml's Queue module, except any function that
reads from or writes to a Queue returns a promise.
Read the documentation for OCaml's Queue module
for more information about the functions in this module *)

(** The type of a thread-safe queue, simply consists
of a Queue.t and a Lwt_mutex.t for protecting it. *)
type 'a t

val create : unit -> 'a t
val add : 'a -> 'a t -> unit Lwt.t
val push : 'a -> 'a t -> unit Lwt.t
val fill_mailbox : 'a Queue.t -> 'a Lwt_mvar.t -> unit Lwt.t
val take_exn : 'a t -> 'a Lwt.t
val take_block : 'a t -> 'a Lwt.t
val take_opt : 'a t -> 'a option Lwt.t
val pop : 'a t -> 'a Lwt.t
val peek : 'a t -> 'a Lwt.t
val peek_opt : 'a t -> 'a option Lwt.t
val top : 'a t -> 'a Lwt.t
val clear : 'a t -> unit Lwt.t
val copy : 'a t -> 'a t Lwt.t
val is_empty : 'a t -> bool Lwt.t
val length : 'a t -> int Lwt.t
val iter : ('a -> unit Lwt.t) -> 'a t -> unit Lwt.t
val fold : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a Lwt.t