(** Types and functions pertaining to clients in a P2P application *)

(** Represents a node with some state in a peer-to-peer network *)
type 'a t

(** Retrieve the Address.t of the given Client.t *)
val address_of : 'a t -> Address.t

(** Constructs a Peer.t from a Client.t *)
val peer_from : 'a t -> Peer.t

(** `create_request client recipient payload` creates a Message.t of the Request category
addressed to `recipient` containing `payload`. *)
val create_request : 'a t ref -> Address.t -> bytes -> Message.t Lwt.t

(** `create_response client request payload` creates a Message.t of the Response category
that responds to `request` whose content is `payload`. *)
val create_response : 'a t ref -> Message.t -> bytes -> Message.t

(** Sends a message via datagram from the given client
to a specified peer. Construct a message with one of the
create functions to then feed to this function. *)
val send_to : 'a t ref -> Message.t -> unit Lwt.t

(** Waits for the next incoming message and returns it *)
val recv_next : 'a t ref -> Message.t Lwt.t

(** Sends an encoded request to the specified peer and
returns a promise holding the response from the peer. This
function blocks the current thread of execution until a response
arrives. *)
val request : 'a t ref -> bytes -> Address.t -> Message.t Lwt.t

(** Broadcasts a request containing the given payload to a list
of recipients and collects the responses in a list of `Message.t Lwt.t`. *)
val broadcast_request :
  'a t ref -> bytes -> Address.t list -> Message.t Lwt.t list

(** Initializes the client with an initial state, an optional
routing function that the consumer can use to inspect and modify
the incoming message as well as its metadata, and a message
handler that acts on the current state and the Message.t representing
the request. The message handler is used
to initialize a server that runs asynchronously. Returns
a reference to the client. *)
val init :
  state:'a ->
  ?router:(Message.t -> Message.t) ->
  msg_handler:('a ref -> Message.t -> bytes) ->
  ?init_peers:Address.t list ->
  string * int ->
  'a t ref Lwt.t
