(** Values wrapped in [Lwt_mutex.t] *)

(** {1 Type} *)

type 'a t
(** A wrapper for a value that needs to be protected by
a mutex. *)

(** {1 API} *)

val create : 'a -> 'a t
(** Creates a mutex-wrapped value. *)

val lock : 'a t -> 'a Lwt.t
(** Locks the mutex protecting the value and
returns a reference to the value so that it can
be mutated. *)

val unlock : 'a t -> unit
(** Unlocks the mutex protecting the value. *)

val is_locked : 'a t -> bool
(** Checks if the mutex is locked. *)

val with_lock : 'a t -> ('a -> 'b Lwt.t) -> 'b Lwt.t
(** Locks the mutex, executes the given function on
the value, unlocks the mutex, then returns the result
of the function call. *)

val unsafe : 'a t -> ('a -> 'b) -> 'b
(** [unsafe t f] applies the function [f] to the value wrapped by [t] 
and returns the result {i without locking the mutex.} *)
