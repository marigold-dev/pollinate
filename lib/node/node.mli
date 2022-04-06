open Common

module Message = Message
module Client = Client

(** Represents a node with some state in a peer-to-peer network *)
type 'a t = 'a Types.node

(** Initializes the node with an initial state, an optional
routing function that the consumer can use to inspect and modify
the incoming message as well as its metadata, and a message
handler that acts on the current state and the Message.t representing
the request. The message handler is used
to initialize a server that runs asynchronously. Returns
a reference to the node. *)
val init :
  state:'a ->
  ?router:(Message.t -> Message.t) ->
  msg_handler:('a ref -> Message.t -> bytes) ->
  ?init_peers:Address.t list ->
  string * int ->
  'a t ref Lwt.t
