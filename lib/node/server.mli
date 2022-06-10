(** Runs the server given a reference to a node, a message preprocessor and a message handler.
    The server is responsible for running failure detection and dissemination processes, as well
    as issuing responses to nodes making individual requests via the message handler. *)
val run :
  Types.node ref ->
  (Message.t -> Message.t) ->
  (Message.t -> bytes option) ->
  'b Lwt.t

val run_background_processes : Types.node ref -> period:float -> unit
