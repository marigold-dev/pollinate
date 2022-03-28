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
  (* Table mapping sequence numbers to condition variables that get
     signalled when a peer that was probed during the period to which
     the sequence number applies replies with acknowledgement. *)
  acknowledges : (int, unit Lwt_condition.t) Base.Hashtbl.t;
  mutable sequence_number : int;
}

let make config =
  { config; acknowledges = Base.Hashtbl.Poly.create (); sequence_number = 0 }

(* Helper to increase the round *)
let next_seq_no t =
  let sequence_number = t.sequence_number in
  t.sequence_number <- t.sequence_number + 1;
  sequence_number

let create_message client message (recipient : Peer.t) =
  Message.
    {
      category = Failure_detection;
      id = -1;
      sender = Client.address_of !client;
      recipient = recipient.address;
      payload = Util.Encoding.pack bin_writer_message message;
    }

let send_message message client (recipient : Peer.t) =
  Client.send_to client (create_message client message recipient)

let send_ping_to client peer = send_message Ping client peer

let send_acknowledge_to client = send_message Acknowledge client

let send_ping_request_to client (recipient : Peer.t) =
  send_message (PingRequest recipient.address) client recipient

let wait_ack t sequence_number =
  let cond =
    Base.Hashtbl.find_or_add t.acknowledges sequence_number
      ~default:Lwt_condition.create in
  Lwt_condition.wait cond

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

(* Regarding the SWIM protocol, if peer A cannot get ACK from peer B (timeout):
   A sets B as `suspicious`
   A randomly picks one (or several, should it also be randomly determined?) peer(s) from its list
   and ask him/them to ping B.*)
(* This function return the random peer, to which we will ask to ping the first peer *)
let rec pick_random_neighbors neighbors number_of_neighbors =
  let addresses = neighbors |> Base.Hashtbl.keys |> knuth_shuffle in
  match addresses with
  | [] -> failwith "pick_random_peers"
  | elem :: _ ->
    if number_of_neighbors = 1 then
      [elem]
    else
      elem :: pick_random_neighbors neighbors (number_of_neighbors - 1)

let update_neighbor_status peer neighbor status =
  let open Peer in
  let local_neighbor = get_neighbor peer neighbor.address in
  match local_neighbor with
  | Some neighbor ->
    neighbor.status <- status;
    Base.Hashtbl.update peer.neighbors neighbor.address ~f:(fun _ -> neighbor)
  | None -> ()

let handle_payload t client peer msg =
  let peer_of_client = Client.peer_from !client in
  match msg with
  | Ping -> send_acknowledge_to client peer
  | PingRequest addr -> (
    let new_seq_no = next_seq_no t in
    let peer_opt = Peer.get_neighbor peer_of_client addr in
    match peer_opt with
    | Some peer -> send_ping_request_to client peer
    | None -> (
      Printf.printf "No peer from address: %s" (Address.show addr);
      match%lwt wait_ack_timeout t new_seq_no t.config.protocol_period with
      | Ok _ -> Lwt.return ()
      | Error _ -> send_acknowledge_to client peer))
  | Acknowledge ->
  match Base.Hashtbl.find t.acknowledges t.sequence_number with
  | Some cond ->
    Lwt_condition.broadcast cond ();
    Lwt.return ()
  | None -> Lwt.return ()

(** This function will be called by failure_detection 
at each round of the protocol, and update the peers *)
let probe_peer t client peer_to_update =
  let peer_of_client = Client.peer_from !client in
  let new_seq_no = next_seq_no t in
  let _ = send_ping_to client peer_to_update in
  match%lwt wait_ack_timeout t new_seq_no t.config.round_trip_time with
  | Ok _ -> Lwt.return ()
  | Error _ -> (
    let pingers =
      t.config.peers_to_ping
      |> pick_random_neighbors peer_of_client.neighbors
      |> List.map Peer.from in
    let _ = List.map (send_ping_request_to client) pingers in
    let wait_time = t.config.protocol_period - t.config.round_trip_time in
    match%lwt wait_ack_timeout t new_seq_no wait_time with
    | Ok _ -> Lwt.return ()
    | Error _ ->
      (* TODO: Implement Suspicion Mechanism.
         This is correct in the basic SWIM protocol, but it is a very heavy penalty.
         When there is no ACK (direct or indirect) the peer must be set to `Suspicious`.
         See section 4.2 from https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf *)
      let _ = update_neighbor_status peer_of_client peer_to_update Faulty in
      Lwt.return ())

(** High level function, which must be run within an async thread, like:
 Lwt.async (fun () -> failure_detection t client); *)
let[@warning "-32"] rec failure_detection t client =
  let open Peer in
  let peer_of_client = Client.peer_from !client in
  let available_peers =
    List.filter
      (fun p -> p.status = Peer.Alive)
      (Base.Hashtbl.data peer_of_client.neighbors) in
  match List.length available_peers with
  | 0 -> failwith "Not any peer is Alive!"
  | _ ->
    let random_peer =
      List.map (fun p -> p.address) available_peers |> knuth_shuffle |> List.hd
    in
    let _ =
      Lwt.join
        [
          probe_peer t client (Peer.from random_peer);
          Lwt_unix.sleep @@ Float.of_int t.config.protocol_period;
        ] in
    failure_detection t client
