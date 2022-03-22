(** Messages sent by the protocol *)
type message =
  | Ping
  | Acknowledge
  | PingRequest of Address.t

(** Here is the definition of the SWIM protocol *)
type config = {
  (* This is the global protocol period, it should be at least three times the round_trip_time *)
  protocol_period : int;
  (* The round trip should be around the 99th percentile *)
  round_trip_time : int;
  (* Number of peers to pick at each round *)
  peers_to_ping : int;
}

(** The state of a failure detection component. *)
type t

(** Initializes the failure detection component
with a default state and given config *)
val create : config -> t

(** At each round, the protocol will randomly pick two peers:
  - First one: will be the sender of the Ping
  - Second one: the recipient *)
val pick_random_peer_addresses :
  (Address.t, Peer.t) Base.Hashtbl.t -> int -> Address.t list

(** Send the provided message to the provided peer, using the provided Client *)
val send_message : message -> 'a Client.t ref -> Peer.t -> unit Lwt.t

(** High level function, which must be run within an async thread, like:
 Lwt.async (fun () -> failure_detection t client); *)
(** Basic random shuffle, see https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle*)
val knuth_shuffle : Address.t list -> Address.t list

val failure_detection : t -> 'a Client.t ref -> 'b