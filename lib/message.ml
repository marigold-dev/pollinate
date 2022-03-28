open Bin_prot.Std

type category =
  | Uncategorized
  | Request
  | Response
  | Failure_detection
  | Custom            of string
[@@deriving bin_io]

type t = {
  category : category;
  id : int;
  sender : Address.t;
  recipient : Address.t;
  payload : bytes;
}
[@@deriving bin_io]