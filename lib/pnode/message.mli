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
  | Request
  | Response
  | Post
  | Failure_detection
  | Custom            of string
[@@deriving bin_io, show, eq, ord]

(** Messages received from [peers] which are
processed by the node's message handler. *)
type t = {
  category : category;
  sub_category_opt : (string * string) option;
  id : int;
  timestamp : float;
  sender : Address.t;
  recipients : Address.t list;
  payload : bytes;
  payload_signature : bytes option;
}
[@@deriving bin_io, eq, ord]

val hash_of : t -> Digest.t