(** Messages sent by the protocol *)
type message =
  | Ping
  | Acknowledge
  | PingRequest of Address.t

(** Here is the definition of the SWIM protocol *)
type config = {
  (* This tis the global protocol period, it should be at least three times the round_trip_time *)
  protocol_period : int;
  (* The round trip should be around the 99th percentile *)
  round_trip_time : int;
  (* NUmber of peers to pick at each round *)
  peers_to_ping : int;
}

(** Type holding all the necessary information for the SWIM protocol *)
type t = {
  config : config;
  acknowledges : (int, unit Lwt_condition.t) Base.Hashtbl.t;
  mutable sequence_number : int;
}

(** Add the provided peer to the known peers from the protocol *)
val add_peer : Peer.t -> Peer.t -> [`Duplicate | `Ok]

(** At each round, the protocol will randomly pick two peers:
  - First one: will be the sender of the Ping
  - Second one: the recipient *)
val pick_random_peer_addresses :
  (Address.t, Peer.t) Base.Hashtbl.t -> int -> Address.t list

(** Basic random shuffle, see https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle*)
val knuth_shuffle : Address.t list -> Address.t list

(** Send the provided message to the provided peer, using the provided Client *)
val send_message : message -> 'a Client.t ref -> Peer.t -> unit Lwt.t

val failure_detection : t -> 'a Client.t ref -> 'b
