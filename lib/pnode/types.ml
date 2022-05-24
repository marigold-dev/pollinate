open Lwt_unix
open Common

type failure_detector_config = {
  protocol_period : int;
  (* TODO: Implement automatic configuration/empirical determination of an ideal round-trip time *)
  round_trip_time : int;
  suspicion_time : int;
  helpers_size : int;
}

type failure_detector = {
  config : failure_detector_config;
  acknowledges : (int, unit Lwt_condition.t) Base.Hashtbl.t;
  mutable sequence_number : int;
}

type node = {
  address : Address.t;
  current_request_id : int ref Mutex.t;
  request_table : (int, Message.t Lwt_condition.t) Hashtbl.t;
  socket : file_descr Mutex.t;
  inbox : Inbox.t;
  failure_detector : failure_detector;
  peers : (Address.t, Peer.t) Base.Hashtbl.t;
}
