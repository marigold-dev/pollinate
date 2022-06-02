open Common
open Bin_prot.Std

type category =
  | Uncategorized
  | Request
  | Response
  | Post
  | Failure_detection
  | Custom            of string
[@@deriving bin_io, show, eq, ord]

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