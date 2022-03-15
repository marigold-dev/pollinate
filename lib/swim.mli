(** Messages sent by the protocol *)
type message =
  | Ping
  | Acknowledge
  | PingRequest of Peer.address

(** Here is the definition of the SWIM protocol *)
type config = {
  (* This tis the global protocol period, it should be at least three times the round_trip_time *)
  protocol_period : int;
  (* The round trip should be around the 99th percentile *)
  round_trip_time : int;
  (* Timeout for Acknowledge message *)
  timeout : int;
}

(** Type holding all the necessary information for the SWIM protocol *)
type t = {
  config : config;
  acknowledges : (int, unit Lwt_condition.t) Base.Hashtbl.t;
  mutable peers : Peer.t list;
  mutable sequence_number : int;
}

(** Add the provided peer to the known peers from the protocol *)
val add_peer : Peer.t -> t -> unit

(** At each round, the protocol will randomly pick two peers:
  - First one: will be the sender of the Ping
  - Second one: the recipient *)
val pick_random_peer : t -> Peer.t

(** Basic random shuffle, see https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle*)
val knuth_shuffle : Peer.t list -> Peer.t list

(** Util function to send the Ping message *)
val send_ping_to : 'a Client.t ref -> Peer.t -> unit Lwt.t

(** Util function to send the Acknowledge message *)
val send_acknowledge_to : 'a Client.t ref -> Peer.t -> unit Lwt.t

(** Util function to send the PingRequest message *)
val send_ping_request_to : 'a Client.t ref -> Peer.t -> unit Lwt.t
