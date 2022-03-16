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
  mutable peers_to_ping : int;
}

type t = {
  config : config;
  (* TODO: I am totally not sure about this type *)
  acknowledges : (int, unit Lwt_condition.t) Poly.t;
  mutable peers : Peer.t list;
  mutable sequence_number : int;
}

(* Helper to increase the round *)
let next_seq_no t =
  let sequence_number = t.sequence_number in
  t.sequence_number <- t.sequence_number + 1;
  sequence_number

let send_message client (recipient : Peer.t) message =
  let message = Util.Encoding.pack bin_writer_message message in
  Client.send_to client message recipient.socket_address

let send_ping_to client recipient = send_message client recipient Ping

let send_acknowledge_to client recipient =
  send_message client recipient Acknowledge

let send_ping_request_to client recipient =
  send_message client recipient (PingRequest recipient.socket_address)

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
let rec pick_random_peers (peers : Peer.t list) number_of_peers =
  match peers with
  | [] -> failwith "pick_random_peers"
  | elem :: list ->
    if number_of_peers = 1 then
      [elem]
    else
      elem :: pick_random_peers list (number_of_peers - 1)

(* TODO: This function will update the status of the peer to Suspicious or Faulty *)
let update_peer t client peer = failwith "undefined"

(* How should I use this function? Let the client of the library defines a `peer.init` using it at `msg_handler`? *)
let handle_payload t client (peer : Peer.t) msg =
  let _ =
    update_peer t client
      Peer.{ status = Alive; socket_address = peer.socket_address } in
  match msg with
  | Ping -> send_acknowledge_to client peer
  | PingRequest addr -> (
    let seq_no = next_seq_no t in
    let _ = send_ping_to client (Peer.retrieve_peer_from_address t.peers addr) in
    match%lwt wait_ack_timeout t seq_no t.config.protocol_period with
    (* TODO: I am not sure about using the backtick character, I think it makes it polymorphic, should we do something like that here? *)
    | Ok _ -> Lwt.return ()
    | Error _ -> send_acknowledge_to client peer)
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
  | Ok _ -> Lwt.return ()
  | Error _ -> (
    let helpers : Peer.t list =
      pick_random_peers t.peers t.config.peers_to_ping in
    let _ = List.map (send_ping_request_to client) helpers in
    let wait_time = t.config.protocol_period - t.config.round_trip_time in
    match%lwt wait_ack_timeout t seq_no wait_time with
    | Ok _ -> Lwt.return ()
    | Error _ ->
      let peer : Peer.t =
        { status = Faulty; socket_address = peer.socket_address } in
      update_peer t !client [peer];
      Lwt.return ())
