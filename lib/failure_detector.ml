type message =
  | Ping
  | Acknowledge
  | PingRequest of Address.t
[@@deriving bin_io]

type config = {
  protocol_period : int;
  round_trip_time : int;
  peers_to_ping : int;
}

type t = {
  config : config;
  (* TODO: I am totally not sure about this type *)
  acknowledges : (int, unit Lwt_condition.t) Base.Hashtbl.t;
  mutable sequence_number : int;
}

(* Helper to increase the round *)
let next_seq_no t =
  let sequence_number = t.sequence_number in
  t.sequence_number <- t.sequence_number + 1;
  sequence_number

let send_message message client (recipient : Peer.t) =
  let message = Util.Encoding.pack bin_writer_message message in
  Client.send_to client message recipient

let send_ping_to client peer =
  match peer with
  | None -> failwith "Trying to send message to nobody)"
  | Some peer -> send_message Ping client peer

let send_acknowledge_to = send_message Acknowledge

let send_ping_request_to client (recipient : Peer.t) =
  send_message (PingRequest recipient.address) client recipient

(* TODO: Totally not sure about this...
   I don't know if I can get rid of it and only use `wait_ack_timeout` instead
    But I feel like Lwt_condition allows ms to manage async thread and could be useful *)
let wait_ack t sequence_number =
  let cond =
    Base.Hashtbl.find_or_add t.acknowledges sequence_number
      ~default:Lwt_condition.create in
  Lwt_condition.wait cond

(* TODO: An async thread should be started here, with a basic sleep, but not sure at all...
     And we should return Either Ok Timeout *)
let wait_ack_timeout t sequence_number timeout =
  Lwt.pick
    [
      (let _ = Lwt_unix.sleep (Float.of_int timeout) in
       Lwt.return @@ Result.Error "Timeout reached");
      (let _ = wait_ack t sequence_number in
       Lwt.return @@ Result.Ok "Successfully received acknowledge");
    ]

(** Basic random shuffle, see https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle*)
let knuth_shuffle known_peers =
  let shuffled_array = Array.copy (Array.of_list known_peers) in
  let initial_array_length = Array.length shuffled_array in
  for i = initial_array_length - 1 downto 1 do
    let k = Random.int (i + 1) in
    let x = shuffled_array.(k) in
    shuffled_array.(k) <- shuffled_array.(i);
    shuffled_array.(i) <- x
  done;
  Array.to_list shuffled_array

(* Regarding the SWIM protocol, the list of peers is not ordered.
   Hence, I basically went for a shuffle after adding the new peer *)
let add_peer (peer : Peer.t) (peer_to_add : Peer.t) =
  Base.Hashtbl.add peer.peers ~key:peer_to_add.address ~data:peer_to_add

(* Regarding the SWIM protocol, if peer A cannot get ACK from peer B (timeout):
   A sets B as `suspicious`
   A randomly picks one (or several, should it also be randomly determined?) peer(s) from its list
   and ask him/them to ping B.*)
(* This function return the random peer, to which we will ask to ping the first peer *)
let rec pick_random_peer_addresses (peers : (Address.t, Peer.t) Base.Hashtbl.t)
    number_of_peers =
  let addresses = peers |> Base.Hashtbl.keys |> knuth_shuffle in
  match addresses with
  | [] -> failwith "pick_random_peers"
  | elem :: _ ->
    if number_of_peers = 1 then
      [elem]
    else
      elem :: pick_random_peer_addresses peers (number_of_peers - 1)

(* Retrieve the peer_to_update from the peers of the given peer
   and update its status to the provided one *)
let update_peer (peer : Peer.t) (peer_to_update : Peer.t) (status : Peer.status)
    =
  let updated_peer =
    Peer.retrieve_peer_from_address_opt peer.peers peer_to_update.address in
  match updated_peer with
  | Some updated_peer ->
    updated_peer.status <- status;
    Base.Hashtbl.update peer.peers updated_peer.address ~f:(fun _ -> peer)
  | None -> ()

(* How should I use this function? Let the client of the library defines a `peer.init` using it at `msg_handler`? *)
let[@warning "-32"] handle_payload t (client : 'a Client.t ref) (peer : Peer.t)
    msg =
  let peer_from = Client.peer_from !client in
  match msg with
  | Ping -> send_acknowledge_to client peer
  | PingRequest addr -> (
    let new_seq_no = next_seq_no t in
    let _ =
      send_ping_to client
        (Peer.retrieve_peer_from_address_opt peer_from.peers addr) in
    match%lwt wait_ack_timeout t new_seq_no t.config.protocol_period with
    | Ok _ -> Lwt.return ()
    | Error _ -> send_acknowledge_to client peer)
  | Acknowledge ->
  match Base.Hashtbl.find t.acknowledges t.sequence_number with
  | Some cond ->
    Lwt_condition.broadcast cond ();
    Lwt.return ()
  | None ->
    (* Unexpected ACK -- ignore *)
    Lwt.return ()

let[@warning "-32"] probe_node t client (peer_to_update : Peer.t) =
  let peer_from = Client.peer_from !client in
  let new_seq_no = next_seq_no t in
  match%lwt wait_ack_timeout t new_seq_no t.config.round_trip_time with
  | Ok _ -> Lwt.return ()
  | Error _ -> (
    let indirect_pingers : Address.t list =
      pick_random_peer_addresses peer_from.peers t.config.peers_to_ping in
    let pingers = List.map Peer.from indirect_pingers in
    let _ = List.map (send_ping_request_to client) pingers in
    let wait_time = t.config.protocol_period - t.config.round_trip_time in
    match%lwt wait_ack_timeout t new_seq_no wait_time with
    | Ok _ -> Lwt.return ()
    | Error _ ->
      (* TODO: Implement Suspicion Mechanism.
         This is correct in the basic SWIM protocol, but it is a very heavy penalty.
         When there is no ACK (direct or indirect) the node must be set to `Suspicious`.
         See section 4.2 from https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf *)
      let _ = update_peer peer_from peer_to_update Faulty in
      Lwt.return ())
