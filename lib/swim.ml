open Base.Hashtbl

type message =
  | Ping
  | Acknowledge
  | PingRequest of Peer.address
[@@deriving bin_io]

type config = {
  protocol_period : int;
  round_trip_time : int;
  timeout : int;
}

type t = {
  config : config;
  (* TODO: I am totally not sure about this type *)
  acknowledges : (int, unit Lwt_condition.t) Poly.t;
  mutable peers : Peer.t list;
  (* TODO: I am not sure this is useful, it's just a counter to know what is the current round
     I would like to send it with the message payload, what do you think? *)
  mutable sequence_number : int;
}

(* Helper to increase the round *)
let next_seq_no t =
  let sequence_number = t.sequence_number in
  t.sequence_number <- t.sequence_number + 1;
  sequence_number

let send_ping_to client (peer_address : Peer.address) =
  let ping = Util.Encoding.pack bin_writer_message Ping in
  Client.send_to client ping peer_address

let send_acknowledge_to client (peer_address : Peer.address) =
  let acknowledge = Util.Encoding.pack bin_writer_message Acknowledge in
  Client.send_to client acknowledge peer_address

let send_ping_request_to client (peer_address : Peer.address) =
  let ping_request =
    Util.Encoding.pack bin_writer_message (PingRequest peer_address) in
  Client.send_to client ping_request peer_address

(* TODO: Totally not sure about this...
   I don't know if I can get rid of it and only use `wait_ack_timeout` instead
    But I feel like Lwt_condition allows ms to manage async thread and could be useful *)
let rec wait_ack t sequence_number =
  let cond =
    find_or_add t.acknowledges sequence_number ~default:Lwt_condition.create
  in
  Lwt_condition.wait cond

(* TODO: An async thread should be started here, with a basic sleep, but not sure at all...
     And we should return Either Ok Timeout *)
let wait_ack_timeout t sequence_number timeout = failwith "undefined"

(* Basic Knuth shuffle => https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle *)
let knuth_shuffle known_peers =
  let initial_array = Array.length (Array.of_list known_peers) in
  let shuffled_array = Array.copy (Array.of_list known_peers) in
  for i = initial_array - 1 downto 1 do
    let k = Random.int (i + 1) in
    let x = shuffled_array.(k) in
    shuffled_array.(k) <- shuffled_array.(i);
    shuffled_array.(i) <- x
  done;
  Array.to_list shuffled_array

(* Regarding the SWIM protocol, the list of peers is not ordered.
   Hence, I basically went for a shuffle after adding the new peer *)
let add_peer peer_to_add t =
  let new_peers = peer_to_add :: t.peers in
  let shuffled_list = knuth_shuffle new_peers in
  t.peers <- shuffled_list

(* Regarding the SWIM protocol, if peer A cannot get ACK from peer B (timeout):
   A sets B as `suspicious`
   A randomly picks one (or several, should it also be randomly determined?) peer(s) from its list
   and ask him/them to ping B.*)
(* This function return the random peer, to which we will ask to ping the first peer *)
let pick_random_peer t =
  let random_int = Random.int (List.length t.peers) - 1 in
  List.nth t.peers random_int

(* TODO: This function will update the status of the peer to Suspicious or Faulty *)
let update_peer t client peer = failwith "undefined"

(* How should I use this function? Let the client of the library defines a `peer.init` using it at `msg_handler`? *)
let handle_payload t client src_addr msg =
  let _ =
    update_peer t client
      ({ status = Alive; socket_address = src_addr } : Peer.t) in
  match msg with
  | Ping -> send_acknowledge_to client src_addr
  | PingRequest addr -> (
    let seq_no = next_seq_no t in
    let _ = send_ping_to client addr in
    match%lwt wait_ack_timeout t seq_no t.config.protocol_period with
    (* TODO: I am not sure about using the backtick character, I think it makes it polymorphic, should we do something like that here? *)
    | `Timeout -> Lwt.return ()
    | `Ok -> send_acknowledge_to client src_addr)
  | Acknowledge ->
  match find t.acknowledges t.sequence_number with
  | Some cond ->
    Lwt_condition.broadcast cond ();
    Lwt.return ()
  | None ->
    (* Unexpected ACK -- ignore *)
    Lwt.return ()

(* TODO: This function should be call in a never endling loop to send the message each N seconds/minutes
   and also update peer status *)
let probe_node t client (peer : Peer.t) =
  let seq_no = next_seq_no t in
  match%lwt wait_ack_timeout t seq_no t.config.round_trip_time with
  | `Ok -> Lwt.return ()
  | `Timeout -> (
    let helper : Peer.t = pick_random_peer t in
    let _ = send_ping_request_to client helper.socket_address in
    let wait_time = t.config.protocol_period - t.config.round_trip_time in
    match%lwt wait_ack_timeout t seq_no wait_time with
    | `Ok -> Lwt.return ()
    | `Timeout ->
      let peer : Peer.t =
        { status = Faulty; socket_address = peer.socket_address } in
      update_peer t !client [peer];
      Lwt.return ())
