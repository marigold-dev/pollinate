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
  acknowledges : (int, unit Lwt_condition.t) Poly.t;
  mutable peers : Peer.t list;
  mutable sequence_number : int;
}

let send_ping_to client (peer : Peer.t) =
  let ping = Util.Encoding.pack bin_writer_message Ping in
  Client.send_to client ping peer.socket_address

let send_acknowledge_to client (peer : Peer.t) =
  let acknowledge = Util.Encoding.pack bin_writer_message Acknowledge in
  Client.send_to client acknowledge peer.socket_address

let send_ping_request_to client (peer : Peer.t) =
  let ping_request =
    Util.Encoding.pack bin_writer_message (PingRequest peer.socket_address)
  in
  Client.send_to client ping_request peer.socket_address

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
