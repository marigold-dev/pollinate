(** Utils function shared by the different tests modules *)
module Messages = struct
  open Bin_prot.Std

  type request =
    | Ping
    | Get
    | Insert of string
  [@@deriving bin_io, show { with_path = false }]

  type response =
    | Pong
    | List    of string list
    | Success of string
    | Error   of string
  [@@deriving bin_io, show { with_path = false }]
end
