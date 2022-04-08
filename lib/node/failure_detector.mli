open Types
open Common

(** Messages sent by the failure detector protocol *)
type message =
  | Ping
  | Acknowledge
  | PingRequest of Address.t
[@@deriving bin_io]

(** Initializes the failure detection component
with a default state and given config *)
val make : failure_detector_config -> failure_detector

(** Processes an incoming message bound for the failure detector of a node *)
val handle_message : 'a node ref -> Message.t -> unit Lwt.t

(** Responsible for the calculation of the status of each node *)
val failure_detection : 'a node ref -> unit Lwt.t

(** If a peer is suspicious for more that failure_detector_config.suspicion_time
 it needs to be deleted from the list of knowns peers *)
val suspicious_detection : 'a node ref -> unit Lwt.t
