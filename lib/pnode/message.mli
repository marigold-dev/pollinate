(** Messages received by the [node], whether they are requests,
responses, or protocol-specific messages. For consumer use
only when implementing a preprocessing function for the
node. *)

open Common

(** {1 Type}*)

(** Messages are {i requests} or {i responses},
determining how they are stored and
where they are handled. *)
type pollinate_category =
  | Uncategorized
  | Acknowledgment
  | Request
  | Response
  | Post
  | Failure_detection
  | Custom            of string
[@@deriving bin_io, show]

type payload = {
  data : bytes;
  signature : bytes option;
}
[@@deriving bin_io]

type operation = {
  category : string;
  name : string option;
}
[@@deriving bin_io]

(** Messages received from [peers] which are
processed by the node's message handler. *)
type t = {
  pollinate_category : pollinate_category;
  operation : operation option;
  request_ack : bool;
  id : int;
  timestamp : float;
  sender : Address.t;
  recipients : Address.t list;
  payload : payload;
}
[@@deriving bin_io]

val hash_of : t -> Digest.t
