open Types
open Common

(** Sends a message via datagram from the given [Types.node]
to a specified peer within the [Message.t]. Construct a message with one of the
[create_*] functions to then feed to this function. *)
val send_to : node ref -> Message.t -> unit Lwt.t

(** Waits for the next incoming message and returns it. *)
val recv_next : node ref -> Message.t Lwt.t

(** Advances a node's disseminator by disseminating the messages in the queue
    and pruning outdated messages from the queue. *)
val disseminate : node ref -> unit Lwt.t

(** Given a Base.Hashtbl of Addresses to Peers and a number n of peers to be
    randomly chosen, returns a list of addresses corresponding to n  *)
val pick_random_neighbors :
  (Address.t, Peer.t) Base.Hashtbl.t -> int -> Address.t list

module Testing : sig
  val knuth_shuffle : 'a list -> 'a list
end
