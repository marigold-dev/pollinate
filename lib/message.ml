type label =
  | Request
  | Response

type t = {
  label : label;
  sender : Peer.t;
  payload : bytes;
}