(** Values wrapped in Lwt_mutex.t *)

(** A wrapper for a value that needs to be protected by
a mutex. *)
type 'a t

(** Creates a mutex-wrapped value *)
val create : 'a -> 'a t

(** Locks the mutex protecting the value and
returns a reference to the value so that it can
be mutated *)
val lock : 'a t -> 'a Lwt.t

(** Unlocks the mutex protecting the value *)
val unlock : 'a t -> unit

(** Checks if the mutex is locked *)
val is_locked : 'a t -> bool

(** Locks the mutex, executes the given function on
the value, unlocks the mutex, then returns the result
of the function call *)
val with_lock : 'a t -> ('a -> 'b Lwt.t) -> 'b Lwt.t

(** `unsafe t f` applies the function f to the value wrapped by t 
and returns the result _without locking the mutex_ *)
val unsafe : 'a t -> ('a -> 'b) -> 'b