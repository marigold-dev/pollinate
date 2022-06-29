open Types

(** Prints a log message with information about the node it pertains to and the current time. *)
let log node _msg =
  let _current_time =
    Unix.time () |> Unix.localtime |> fun tm ->
    Printf.sprintf "%02d:%02d:%02d" tm.Unix.tm_hour tm.Unix.tm_min
      tm.Unix.tm_sec in
  let _addr = Printf.sprintf "%s:%d" !node.address.address !node.address.port in
  Lwt.return ()
  (* Lwt_io.printf "[%s @ %s] %s" addr current_time msg *)
