(** Messages received by the [node], whether they are requests,
responses, or protocol-specific messages. For consumer use
only when implementing a preprocessing function for the
node. *)

open Common

(** {1 Type}*)

(** Messages are {i requests} or {i responses},
determining how they are stored and
where they are handled. *)
type category =
  | Uncategorized
  | Acknowledgment
  | Request
  | Response
  | Post
  | Failure_detection
  | Custom            of string
[@@deriving bin_io, show]

(** Messages received from [peers] which are
processed by the node's message handler. *)
type t = {
  category : category;
  sub_category : (string * string) option;
  request_ack : bool;
  id : int;
  timestamp : float;
  sender : Address.t;
  recipients : Address.t list;
  payload : bytes;
  payload_signature : bytes option;
}
[@@deriving bin_io]

type msg = {
  payload : bytes;
  payload_signature : bytes option;
}
[@@deriving bin_io]

val hash_of : t -> Digest.t
