(** Utils function shared by the different tests modules *)
module Commons = struct
  open Bin_prot.Std
  open Pollinate
  open Pollinate.Util

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

  type message =
    | Request  of request
    | Response of response
  [@@deriving bin_io, show { with_path = false }]

  type state = string list

  let protocol : Failure_detector.t =
    let config =
      Failure_detector.
        { protocol_period = 5; round_trip_time = 2; peers_to_ping = 1 } in
    Failure_detector.make config

  let router sender msg =
    let msg = Encoding.unpack bin_read_message msg in
    match msg with
    | Request r ->
      Message.
        {
          label = Message.Request;
          sender;
          payload = Encoding.pack bin_writer_request r;
        }
    | Response r ->
      Message.
        {
          label = Message.Response;
          sender;
          payload = Encoding.pack bin_writer_response r;
        }

  let msg_handler state request =
    let open Message in
    let request = Encoding.unpack bin_read_request request.payload in
    let response =
      match request with
      | Ping -> Pong
      | Get -> List !state
      | Insert s ->
        state := s :: !state;
        Success "Successfully added value to state" in
    Encoding.pack bin_writer_message (Response response)

  (* Initializes four clients and the related four peers *)
  let client_a =
    Lwt_main.run
      (Client.init ~router ~state:["test1"] ~msg_handler ("127.0.0.1", 3000))

  let peer_a = Client.peer_from !client_a

  let client_b =
    Lwt_main.run
      (Client.init ~router ~state:["test2"] ~msg_handler ("127.0.0.1", 3001))

  let peer_b = Client.peer_from !client_b

  let client_c =
    Lwt_main.run
      (Client.init ~router ~state:["test1"] ~msg_handler ("127.0.0.1", 3002))

  let peer_c = Client.peer_from !client_c

  let client_d =
    Lwt_main.run
      (Client.init ~router ~state:["test2"] ~msg_handler ("127.0.0.1", 3003))

  let peer_d = Client.peer_from !client_d
end
