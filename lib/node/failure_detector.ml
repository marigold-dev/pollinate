open Common
open Common.Util
open Types

type message =
  | Ping
  | Acknowledge
  | PingRequest of Address.t
[@@deriving bin_io]

let make config =
  { config; acknowledges = Base.Hashtbl.Poly.create (); sequence_number = 0 }

(** Helper to increase the round at each new protocol_period *)
let next_seq_no t =
  let sequence_number = t.sequence_number in
  t.sequence_number <- t.sequence_number + 1;
  sequence_number

(** Adds the Ack when received *)
let wait_ack t sequence_number =
  let cond =
    Base.Hashtbl.find_or_add t.acknowledges sequence_number
      ~default:Lwt_condition.create in
  Lwt_condition.wait cond

(** Simple racing between getting Ack message or timeout ending *)
let wait_ack_timeout t sequence_number timeout =
  Lwt.pick
    [
      (let _ = Lwt_unix.sleep @@ Float.of_int timeout in
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

(** This function return the random peer, to which we will ask to ping the first peer *)
let rec pick_random_neighbors neighbors number_of_neighbors =
  let addresses = neighbors |> Base.Hashtbl.keys |> knuth_shuffle in
  match addresses with
  | [] -> failwith "pick_random_peers"
  | elem :: _ ->
    if number_of_neighbors = 1 then
      [elem]
    else
      elem :: pick_random_neighbors neighbors (number_of_neighbors - 1)

(** Updates a peer in the node's peer list with
   the given status. Returns a result that contains
   unit if the peer is found in the node's list, and
   a string stating that a peer with the given address
   could not be found otherwise. *)
let update_peer_status node peer status =
  let open Peer in
  let open Unix in
  let neighbor = Base.Hashtbl.find !node.peers peer.address in
  match neighbor with
  | Some neighbor -> (
    neighbor.status <- status;
    match status with
    | Suspicious ->
      let time = gmtime @@ time () in
      neighbor.last_suspicious_status <- Some time;
      Result.Ok ()
    | _ ->
      neighbor.last_suspicious_status <- None;
      Result.Ok ())
  | None ->
    Result.Error
      (Printf.sprintf "Failed to find peer with address %s:%d in node peer list"
         peer.address.address peer.address.port)

let create_message node message (recipient : Peer.t) =
  Message.
    {
      category = Failure_detection;
      id = -1;
      sender = Client.address_of !node;
      recipient = recipient.address;
      payload = Encoding.pack bin_writer_message message;
    }

let send_message message node (recipient : Peer.t) =
  let message = create_message node message recipient in
  Client.send_to node message

let send_ping_to node peer = send_message Ping node peer

let send_acknowledge_to node peer = send_message Acknowledge node peer

let send_ping_request_to node (recipient : Peer.t) =
  send_message (PingRequest recipient.address) node recipient

let handle_message node message =
  let open Message in
  let peer = Peer.from message.sender in
  let msg = Encoding.unpack bin_read_message message.payload in
  let t = !node.failure_detector in
  match msg with
  | Ping -> send_acknowledge_to node peer
  | PingRequest addr -> (
    let new_seq_no = next_seq_no t in
    let peer_opt = Base.Hashtbl.find !node.peers addr in
    match peer_opt with
    | Some peer -> send_ping_request_to node peer
    | None -> (
      match%lwt wait_ack_timeout t new_seq_no t.config.protocol_period with
      | Ok _ -> Lwt.return ()
      | Error _ -> send_acknowledge_to node peer))
  | Acknowledge ->
  match Base.Hashtbl.find t.acknowledges t.sequence_number with
  | Some cond ->
    Lwt_condition.broadcast cond ();
    Lwt.return ()
  | None -> Lwt.return ()

(** This function will be called by failure_detection 
at each round of the protocol, and update the peers *)
let probe_peer t node peer_to_update =
  let new_seq_no = next_seq_no t in
  let _ = send_ping_to node peer_to_update in
  match%lwt wait_ack_timeout t new_seq_no t.config.round_trip_time with
  | Ok _ ->
    (* if we received the ack, we should override peer status to Alive *)
    let _ = update_peer_status node peer_to_update Alive in
    (* TODO: regarding SWIM protocol, a `peer_to_update is suspect` message must be sent
       to every peers known by the node *)
    Lwt.return ()
  | Error _ -> (
    let pingers =
      t.config.helpers_size
      |> pick_random_neighbors !node.peers
      |> List.map Peer.from in
    let _ = List.map (send_ping_request_to node) pingers in
    let wait_time = t.config.protocol_period - t.config.round_trip_time in
    match%lwt wait_ack_timeout t new_seq_no wait_time with
    | Ok _ ->
      let _ = update_peer_status node peer_to_update Alive in
      Lwt.return ()
    | Error _ ->
      let _ = update_peer_status node peer_to_update Suspicious in
      (* TODO: A `peer_to_update is suspect` message must be sent to every peers known by the node *)
      Lwt.return ())

let failure_detection node =
  let open Peer in
  let t = !node.failure_detector in
  let available_peers =
    List.filter (fun p -> p.status = Peer.Alive) (Base.Hashtbl.data !node.peers)
  in
  match List.length available_peers with
  | 0 -> Lwt.return ()
  | _ ->
    let random_peer =
      List.map (fun p -> p.address) available_peers |> knuth_shuffle |> List.hd
    in
    let _ =
      Lwt.join
        [
          probe_peer t node (Peer.from random_peer);
          Lwt_unix.sleep @@ Float.of_int t.config.protocol_period;
        ] in
    Lwt.return ()

module PeerSet = Set.Make (struct
  let compare = Stdlib.compare
  type t = Peer.t
end)

let suspicious_detection node =
  let open Peer in
  let open Unix in
  let t = !node.failure_detector in
  let%lwt () = Lwt_unix.sleep @@ Float.of_int t.config.suspicion_time in
  let suspicious_peers =
    List.filter
      (fun p -> p.status = Peer.Suspicious)
      (Base.Hashtbl.data !node.peers)
    |> List.filter (fun p ->
           p.last_suspicious_status < Some (gmtime @@ time ())) in
  let _ =
    List.iter
      (fun (p : Peer.t) -> Base.Hashtbl.remove !node.peers p.address)
      suspicious_peers in
  (* TODO: this is where Faulty status is used
     We should then send a `peer_a is Faulty` message to every known_peers
     and each of these peers must remove it from its inner known_peers list *)
  Lwt.return ()
