(** Thread-safe queues with the same exact interface
as OCaml's Queue module, except any function that
reads from or writes to a Queue returns a promise.
Furthermore, there is a special take function for blocking
the current thread until an element is available to take
from the queue.
Read the documentation for OCaml's Queue module
for more information about the functions in this module *)

(** The type of a thread-safe queue *)
type 'a t

val create : unit -> 'a t
val add : 'a -> 'a t -> unit Lwt.t
val push : 'a -> 'a t -> unit Lwt.t
val take : 'a t -> 'a option Lwt.t
(** Blocks the current thread of execution until
an element is in the queue, then returns a promise
containing the element *)
val wait_to_take : 'a t -> 'a Lwt.t
val pop : 'a t -> 'a option Lwt.t
val peek : 'a t -> 'a option Lwt.t
val top : 'a t -> 'a option Lwt.t
val clear : 'a t -> unit Lwt.t
val copy : 'a t -> 'a t Lwt.t
val is_empty : 'a t -> bool Lwt.t
val length : 'a t -> int Lwt.t