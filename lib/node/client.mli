(**  Client operations on a node in a P2P application. *)

open Common
open Types

(** {1 API} *)

(** Retrieve the [Address.t] of the given [Types.node]. *)
val address_of : node -> Address.t

(** Constructs a [Peer.t] from a [Types.node]. *)
val peer_from : node -> Peer.t

(** Add a peer to the known peers by the peer's address. *)
val add_peer : node -> Address.t -> [`Duplicate | `Ok]

(** Add a peer, along with all its existing state, to the known peers. *)
val add_peer_as_is : node -> Peer.t -> [`Duplicate | `Ok]

(** Get a list of addresses corresponding to peers of the given node. *)
val peers : node -> Address.t list

(** Begins disseminating an encoded message meant to be witnessed by the
    entire network. *)
val post : node ref -> Message.t -> unit

(** [create_request node recipient payload] creates a [Message.t] of the {i Request category}
addressed to {i recipient} containing {i payload}. *)
val create_request :
  node ref ->
  ?request_ack:bool ->
  Address.t ->
  bytes * bytes option ->
  Message.t Lwt.t

(** [create_response node request payload] creates a [Message.t] of the {i Response category}
that responds to {i request} whose content is {i payload}. *)
val create_response :
  node ref ->
  ?request_ack:bool ->
  Message.t ->
  bytes * bytes option ->
  Message.t

(** Sends an encoded {i request} to the specified peer and
returns a promise holding the response from the peer. This
function blocks the current thread of execution until a response
arrives. *)
val request : node ref -> bytes * bytes option -> Address.t -> Message.t Lwt.t

(** [create_post node payload] creates a [Message.t] of the {i Post category}
    containing {i payload} for eventual gossip dissemination across the
    entire network. *)
val create_post :
  node ref -> ?request_ack:bool -> bytes * bytes option -> Message.t

val create_ack : node ref -> Message.t -> Message.t
