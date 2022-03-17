(** Messages received by the client, whether they're requests,
responses, or protocol-specific messages. For consumer use
only when implementing a routing function for the
client. *)

(** Messages are requests or responses,
determining how they're stored and
where they're handled *)
type label =
  | Request
  | Response

(** Messages received from peers which are
stored in the client's inbox *)
type t = {
  label : label;
  sender : Peer.t;
  payload : bytes;
}