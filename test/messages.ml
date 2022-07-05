(** A peer must handle two kind of messages:
  - Request, which are messages to send
  - Response, which are response from the previous request they sent
  For example, if node_a sends a `Request Ping` to node_b,
    node_b will send a `Response Pong` message to node_a *)
module Messages = struct
  open Bin_prot.Std

  type request =
    | Ping
    | Get
    | Insert of string
  [@@deriving bin_io, show { with_path = false }]

  type response =
    | Pong
    | List of string list
    | Success of string
    | Error of string
  [@@deriving bin_io, show { with_path = false }]

  type message =
    | Request of request
    | Response of response
  [@@deriving bin_io, show { with_path = false }]
end
