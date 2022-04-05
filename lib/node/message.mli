(** Messages received by the node, whether they're requests,
responses, or protocol-specific messages. For consumer use
only when implementing a routing function for the
node. *)
open Common

(** Messages are requests or responses,
determining how they're stored and
where they're handled *)
type category =
  | Uncategorized
  | Request
  | Response
  | Failure_detection
  | Custom            of string
[@@deriving bin_io]

(** Messages received from peers which are
stored in the node's inbox *)
type t = {
  category : category;
  id : int;
  sender : Address.t;
  recipient : Address.t;
  payload : bytes;
}
[@@deriving bin_io]
