open Common

module Message = Message
module Client = Client
module Failure_detector = Failure_detector
module Inbox = Inbox

(** Initializes the node with an initial state, an optional
routing function that the consumer can use to inspect and modify
the incoming message as well as its metadata, and a message
handler that acts on the current state and the Message.t representing
the request. The message handler is used
to initialize a server that runs asynchronously. Returns
a reference to the node. *)
val init :
  ?preprocess:(Message.t -> Message.t) ->
  msg_handler:(Message.t -> bytes * bytes option) ->
  ?init_peers:Address.t list ->
  string * int ->
  Types.node ref Lwt.t
