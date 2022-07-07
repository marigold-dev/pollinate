open Common
open Bin_prot.Std

type category =
  | Uncategorized
  | Acknowledgment
  | Request
  | Response
  | Post
  | Failure_detection
  | Custom            of string
[@@deriving bin_io, show]

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

let hash_of m =
  [
    m.sender.address;
    string_of_int m.sender.port;
    string_of_float m.timestamp;
    Bytes.to_string m.payload;
  ]
  |> String.concat ""
  |> Digest.string
  |> Digest.to_hex
  |> fun s -> String.sub s 0 7
