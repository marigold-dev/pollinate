open Common
open Lwt_unix

(** {1 Types} *)

(** Configurable parameters that affect various aspects of the failure
detector *)
type failure_detector_config = {
  (* The period of time within which peers may be randomly chosen
     to be pinged, and within which any peer who has been pinged must
     respond with an acknowledgement message to continue being considered
     alive to other nodes in the network. The protocol period should
     be at least three times the round_trip_time. *)
  protocol_period : int;
  (* The amount of time a node performing a random-probe of a
     peer will wait before asking other active peers to probe the
     same peer. This value must be at most a third of the protocol period,
     but it is best if it is chosen empirically. *)
  round_trip_time : int;
  (* The amount of time a peer is suspect. After this delay,
     the peer will be declared as Faulty and removed from the know_peers list of the node *)
  suspicion_time : int;
  (* The size of 'failure detection subgroups'. In other words, the
     number of peers that will be asked to ping a suspicious node which
     has failed to respond with acknowledgement during the round_trip_time. *)
  helpers_size : int;
}

(** The state of a failure detection component. *)
type failure_detector = {
  config : failure_detector_config;
  (* Table mapping sequence numbers to condition variables that get
      signalled when a peer that was probed during the period to which
      the sequence number applies replies with acknowledgement. *)
  acknowledges : (int, unit Lwt_condition.t) Base.Hashtbl.t;
  mutable sequence_number : int;
}

module AddressSet : Set.S with type elt = Address.t

(** Represents a node with some state in a peer-to-peer network *)
type node = {
  address : Address.t;
      (* An ID that is incremented whenever a request is
         made from this node. The response matching this
         request will carry the same ID, allowing the response
         to be identified and thus stopping the request from
         blocking. *)
  current_request_id : int ref Mutex.t;
      (* A hashtable that pairs request IDs with condition variables.
         When a response is received by the server, it checks this table
         for a waiting request and signals the request's condition variable
         with the incoming response. *)
  request_table : (int, Message.t Lwt_condition.t) Hashtbl.t;
  socket : file_descr Mutex.t;
  (* Failure detection component ; runs automatically with the server and is responsible
     for automatically removing dead nodes from the peers table. *)
  failure_detector : failure_detector;
  (* Hashtable mapping message hashes to
     peers who have acknowledged the corresponding message. *)
  acknowledgments : (string, AddressSet.t) Hashtbl.t;
  (* Hashtable mapping addresses to Peers with statuses according
     to the SWIM failure-detection protocol *)
  peers : (Address.t, Peer.t) Base.Hashtbl.t;
  (* Dissemination component ; runs automatically with the server and is responsible
     for automatically disseminating both new Post messages and received Post messages
     with other nodes in the network *)
  mutable disseminator : Disseminator.t;
}
