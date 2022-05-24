(** Messages received by the [node], whether they are requests,
responses, or protocol-specific messages. For consumer use
only when implementing a routing function for the
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
  | Failure_detection
  | Custom            of string
[@@deriving bin_io, eq, ord]

(** Messages received from [peers] which are
stored in the node's inbox. *)
type t = {
  category : category;
  sub_category_opt : (string * string) option;
  id : int;
  sender : Address.t;
  recipient : Address.t;
  payload : bytes;
  payload_signature : bytes option;
}
[@@deriving bin_io, eq, ord]
