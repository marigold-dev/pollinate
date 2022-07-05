open Common
module Message = Message
module Client = Client

type t = Types.node

(** Initializes the node with an initial state, an optional
preprocessing function that the consumer can use to inspect and modify
the incoming message as well as its metadata, and a message
handler that acts on the current state and the incoming Message.t.
The message handler is used to initialize a server that runs asynchronously.
Returns reference to the newly created node. *)
val init : ?init_peers:Address.t list -> Address.t -> t ref Lwt.t

val run_server :
  ?preprocessor:(Message.t -> Message.t) ->
  msg_handler:(Message.t -> bytes option * bytes option) ->
  t ref ->
  'b Lwt.t

val seen : t ref -> Message.t -> bool

module Testing : sig
  module AddressSet = Types.AddressSet
  module Failure_detector = Failure_detector
  module Networking = Networking

  val broadcast_queue : t ref -> Message.t list

  val disseminator_round : t ref -> int
end
