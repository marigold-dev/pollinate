type category =
  | Uncategorized
  | Request
  | Response

type t = {
  category : category;
  sender : Peer.t;
  payload : bytes;
}