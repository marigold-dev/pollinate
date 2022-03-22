(** Fast, automatic detection and dissemination of peers dying
or leaving the network. Runs asynchronously as part of the client
and works to maintain a membership list of active nodes. *)

(** Messages sent by the failure detector protocol *)
type message =
  | Ping
  | Acknowledge
  | PingRequest of Address.t

(** Configurable parameters that affect various aspects of the failure
detector *)
type config = {
  (** The period of time within which peers may be randomly chosen
  to be pinged, and within which any peer who has been pinged must
  respond with an acknowledgement message to continue being considered
  alive to other nodes in the network. The protocol period should
  be at least three times the round_trip_time. *)
  protocol_period : int;
 
  (* TODO: Implement automatic configuration/empirical determination of an ideal round-trip time *)
  (** The amount of time a node performing a random-probe of a
  peer will wait before asking other active peers to probe the
  same peer. This value must be at most a third of the protocol period,
  but it is best if it is chosen empirically. *)
  round_trip_time : int;
  (** The size of 'failure detection subgroups'. In other words, the 
  number of peers that will be asked to ping a suspicious node which
  has failed to respond with acknowledgement during the round_trip_time. *)
  peers_to_ping : int;
}

(** The state of a failure detection component. *)
type t

(** Initializes the failure detection component
with a default state and given config *)
val create : config -> t

(* (** At each round, the protocol will randomly pick two peers:
  - First one: will be the sender of the Ping
  - Second one: the recipient *)
val pick_random_peer_addresses :
  (Address.t, Peer.t) Base.Hashtbl.t -> int -> Address.t list *)

(** Processes an incoming message bound for the failure detector *)
val handle_payload : t -> 'a Client.t ref -> Peer.t -> message -> unit Lwt.t

(** High level function, which must be run within an async thread, like:
 Lwt.async (fun () -> failure_detection t client); *)
val failure_detection : t -> 'a Client.t ref -> 'b