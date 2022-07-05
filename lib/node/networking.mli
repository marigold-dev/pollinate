open Types
open Common

val send_to : node ref -> Message.t -> unit Lwt.t
(** Sends a message via datagram from the given [Types.node]
to a specified peer within the [Message.t]. Construct a message with one of the
[create_*] functions to then feed to this function. *)

val recv_next : node ref -> Message.t Lwt.t
(** Waits for the next incoming message and returns it. *)

val disseminate : node ref -> unit Lwt.t
(** Advances a node's disseminator by disseminating the messages in the queue
    and pruning outdated messages from the queue. *)

val pick_random_neighbors :
  (Address.t, Peer.t) Base.Hashtbl.t -> int -> Address.t list
(** Given a Base.Hashtbl of Addresses to Peers and a number n of peers to be
    randomly chosen, returns a list of addresses corresponding to n  *)

module Testing : sig
  val knuth_shuffle : 'a list -> 'a list
end
