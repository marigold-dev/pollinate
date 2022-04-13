(**  Client operations on a node in a P2P application *)

open Common
open Types

(** Retrieve the Address.t of the given node *)
val address_of : 'a node -> Address.t

(** Constructs a Peer.t from a node *)
val peer_from : 'a node -> Peer.t

(** Add a peer to the know peers *)
val add_peer : 'a node -> Peer.t -> [`Duplicate | `Ok]

(** `create_request node recipient payload` creates a Message.t of the Request category
addressed to `recipient` containing `payload`. *)
val create_request : 'a node ref -> Address.t -> bytes -> Message.t Lwt.t

(** `create_response node request payload` creates a Message.t of the Response category
that responds to `request` whose content is `payload`. *)
val create_response : 'a node ref -> Message.t -> bytes -> Message.t

(** Sends a message via datagram from the given node
to a specified peer. Construct a message with one of the
create functions to then feed to this function. *)
val send_to : 'a node ref -> Message.t -> unit Lwt.t

(** Waits for the next incoming message and returns it *)
val recv_next : 'a node ref -> Message.t Lwt.t

(** Sends an encoded request to the specified peer and
returns a promise holding the response from the peer. This
function blocks the current thread of execution until a response
arrives. *)
val request : 'a node ref -> bytes -> Address.t -> Message.t Lwt.t

(** Broadcasts a request containing the given payload to a list
of recipients and collects the responses in a list of `Message.t Lwt.t`. *)
val broadcast_request :
  'a node ref -> bytes -> Address.t list -> Message.t Lwt.t list
