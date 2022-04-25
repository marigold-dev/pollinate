(** Thread-safe queues with the same exact interface
as OCaml's Queue module, except any function that
reads from or writes to a [Queue] returns a promise.
Furthermore, there is a special take function for blocking
the current thread until an element is available to take
from the queue.
Read the {{:https://ocaml.org/api/Queue.html}documentation for OCaml's Queue module}
for more information about the functions in this module *)

(** {1 Type} *)

(** The type of a thread-safe queue *)
type 'a t

(** {1 API} *)

(** Blocks the current thread of execution until
an element is in the queue, then returns a promise
containing the element. *)
val wait_to_take : 'a t -> 'a Lwt.t

(** Similar to [wait_to_take] but doesn't block
    the current thread. *)
val take : 'a t -> 'a option Lwt.t

(** Similar to [wait_to_take], but doesn't remove
from the queue. *)
val wait_to_peek : 'a t -> 'a Lwt.t

(** Similar to [wait_to_peek] but doesn't block
    the current thread. *)
val peek : 'a t -> 'a option Lwt.t

(**/**)

val create : unit -> 'a t

val add : 'a -> 'a t -> unit Lwt.t

val push : 'a -> 'a t -> unit Lwt.t

val pop : 'a t -> 'a option Lwt.t

val top : 'a t -> 'a option Lwt.t

val clear : 'a t -> unit Lwt.t

val copy : 'a t -> 'a t Lwt.t

val is_empty : 'a t -> bool Lwt.t

val length : 'a t -> int Lwt.t

(**/**)
