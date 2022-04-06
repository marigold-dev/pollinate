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

(** High level function, which must be run within an async thread, like:
Lwt.async (fun () -> failure_detection t node); *)
val failure_detection : 'a node ref -> unit Lwt.t
