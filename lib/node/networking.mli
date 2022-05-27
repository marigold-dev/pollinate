open Types

(** Sends a message via datagram from the given [Types.node]
to a specified peer within the [Message.t]. Construct a message with one of the
[create_*] functions to then feed to this function. *)
val send_to : node ref -> Message.t -> unit Lwt.t

(** Waits for the next incoming message and returns it. *)
val recv_next : node ref -> Message.t Lwt.t

val disseminate : node ref -> unit Lwt.t
