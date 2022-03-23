(** Utils function shared by the different tests modules *)
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

  let protocol : Failure_detector.t =
    let config =
      Failure_detector.
        { protocol_period = 5; round_trip_time = 2; peers_to_ping = 1 } in
    Failure_detector.create config

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

  (* Initializes four clients and the related four peers *)
  let client_a =
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3000))
  let peer_a = Peer.from (Client.address_of !client_a)

  let client_b =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3001))
  let peer_b = Peer.from (Client.address_of !client_b)

  let client_c =
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3002))
  let peer_c = Peer.from (Client.address_of !client_c)

  let client_d =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3003))
  let peer_d = Peer.from (Client.address_of !client_d)
end
