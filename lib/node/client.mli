(**  Client operations on a node in a P2P application. *)

open Common
open Types

(** {1 API} *)

(** Retrieve the [Address.t] of the given [Types.node]. *)
val address_of : node -> Address.t

(** Constructs a [Peer.t] from a [Types.node]. *)
val peer_from : node -> Peer.t

(** Add a peer to the known peers. *)
val add_peer : node -> Peer.t -> [`Duplicate | `Ok]

(** Begins disseminating an encoded message meant to be witnessed by as many
    nodes in the network as possible. *)
val post : node ref -> Message.t -> unit

(** [create_request node recipient payload] creates a [Message.t] of the {i Request category}
addressed to {i recipient} containing {i payload}. *)
val create_request : node ref -> Address.t -> bytes -> Message.t Lwt.t

(** [create_response node request payload] creates a [Message.t] of the {i Response category}
that responds to {i request} whose content is {i payload}. *)
val create_response : node ref -> Message.t -> bytes -> Message.t

(** Sends an encoded {i request} to the specified peer and
returns a promise holding the response from the peer. This
function blocks the current thread of execution until a response
arrives. *)
val request : node ref -> bytes -> Address.t -> Message.t Lwt.t

(** Broadcasts a request containing the given payload to a list
of recipients and collects the responses in a list of [Message.t Lwt.t]. *)
val broadcast_request :
  node ref -> bytes -> Address.t list -> Message.t Lwt.t list

val create_post : node ref -> bytes -> Message.t
