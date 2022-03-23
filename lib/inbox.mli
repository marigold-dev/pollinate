(** A Hashtbl mapping message categories to thread-safe queues
containing messages *)
type t

(** Initializes an inbox with queues for each type of message. *)
val create : unit -> t

(** Attempts to retrieve the next message of the given category
from the inbox, and returns None if no message is found. If consume
is true, then the if a message is found it will be removed from the
queue. Otherwise, it will be peeked at but not removed. Creates
a queue for the given category if one has not been created yet. *)
val next : t -> ?consume:bool -> Message.category -> Message.t option Lwt.t

(** Blocks the current thread of execution until a message of the specified
category is available. If consume is true, the message will be
removed from the queue once it is available. Otherwise, it will be
peeked at. Creates a queue for the given category if one has not
    been created yet. *)
val await_next : t -> ?consume:bool -> Message.category -> Message.t Lwt.t

(** Pushes the given message of the given category
to the corresponding queue. Creates a queue for the given category
if one has not been created yet. *)
val push : t -> Message.category -> Message.t -> unit Lwt.t