(**  Client operations on a node in a P2P application. *)

open Common
open Types

(** {1 API} *)

(** Retrieve the [Address.t] of the given [Types.node]. *)
val address_of : node -> Address.t

(** Constructs a [Peer.t] from a [Types.node]. *)
val peer_from : node -> Peer.t

(** Add a peer to the know peers. *)
val add_peer : node -> Peer.t -> [`Duplicate | `Ok]

(** [create_request node recipient payload] creates a [Message.t] of the {i Request category}
addressed to {i recipient} containing {i payload}. *)
val create_request :
  node ref ->
  Address.t ->
  sign_payload:(bytes -> bytes option -> bytes option) ->
  key:bytes option ->
  bytes ->
  Message.t Lwt.t

(** [create_response node request payload] creates a [Message.t] of the {i Response category}
that responds to {i request} whose content is {i payload}. *)
val create_response :
  node ref ->
  Message.t ->
  sign_payload:(bytes -> bytes option -> bytes option) ->
  key:bytes option ->
  bytes ->
  Message.t

(** Sends a message via datagram from the given [Types.node]
to a specified peer within the [Message.t]. Construct a message with one of the
[create_*] functions to then feed to this function. *)
val send_to : node ref -> Message.t -> unit Lwt.t

(** Waits for the next incoming message and returns it. *)
val recv_next : node ref -> Message.t Lwt.t

(** Sends an encoded {i request} to the specified peer and
returns a promise holding the response from the peer. This
function blocks the current thread of execution until a response
arrives. *)
val request :
  node ref ->
  sign_payload:(bytes -> bytes option -> bytes option) ->
  key:bytes option ->
  bytes ->
  Address.t ->
  Message.t Lwt.t

(** Broadcasts a request containing the given payload to a list
of recipients and collects the responses in a list of [Message.t Lwt.t]. *)
val broadcast_request :
  node ref ->
  Address.t list ->
  sign_payload:(bytes -> bytes option -> bytes option) ->
  key:bytes option ->
  bytes ->
  Message.t Lwt.t list
