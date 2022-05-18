(** Implementation of the {{:https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf} SWIM protocol.}

  {1 Introduction}

  This module is composed of two main functions:
  - [failure_detection]: which goal is to calculate if a know peer is Alive or Suspicious, then disseminate the new status.
  - [suspicious_detection]: which goal is to handle the Suspicious peers, and flag them as Faulty if timeout has expired, then disseminate the new status. *)

open Types
open Common

(** {1 Type}*)

(** Messages sent by the failure detector protocol. *)
type message =
  | Ping
  | Acknowledge
  | PingRequest of Address.t
[@@deriving bin_io]

(** {1 Constructor} *)

(** Initializes the failure detection component
with a default state and given config. *)
val make : failure_detector_config -> failure_detector

(** {1 Messaging} *)

(** Processes an incoming [Message.t] bound for the failure detector of a node. *)
val handle_message : node ref -> Message.t -> unit Lwt.t

(** {1 Detection functions} *)

(** Responsible for the calculation of the status of each node *)
val suspicion_detection : node ref -> unit Lwt.t

(** If a peer is suspicious for more that failure_detector_config.suspicion_time
 it needs to be deleted from the list of knowns peers *)
val failure_detection : node ref -> unit Lwt.t

(**/**)

val knuth_shuffle : Peer.t list -> Peer.t list

val pick_random_neighbors : ('a, 'b) Base.Hashtbl.t -> int -> 'a list

val update_peer_status :
  Types.node ref -> Common.Peer.t -> Common.Peer.status -> (unit, string) result

(**/**)
