open Common
open Bin_prot.Std

type category =
  | Uncategorized
  | Request
  | Response
  | Failure_detection
  | Custom            of string
[@@deriving bin_io, eq, ord]

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
