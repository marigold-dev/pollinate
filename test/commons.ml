module Commons = struct
  open Bin_prot.Std
  open Pollinate
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

  type state = string list

  let msg_handler state _ request =
    let request = Util.Encoding.unpack bin_read_request request in
    let response =
      match request with
      | Ping -> Pong
      | Get -> List !state
      | Insert s ->
        state := s :: !state;
        Success "Successfully added value to state" in
    Util.Encoding.pack bin_writer_response response

  let client_a =
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3000))
  let peer_a = Client.peer_from !client_a

  let client_b =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3001))
  let peer_b = Client.peer_from !client_b

  let client_c =
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3002))
  let peer_c = Client.peer_from !client_c

  let client_d =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3003))
  let peer_d = Client.peer_from !client_d
end
