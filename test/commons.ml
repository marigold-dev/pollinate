(** Utils function shared by the different tests modules *)
module Commons = struct
  open Pollinate.Node
  open Pollinate.Util
  open Messages

  type state = string list

  let preprocess msg =
    let open Messages in
    match msg.Message.category with
    | Request ->
      let[@warning "-8"] (Request r) =
        Encoding.unpack bin_read_message msg.Message.payload in
      { msg with payload = Encoding.pack bin_writer_request r }
    | Response ->
      let[@warning "-8"] (Response r) =
        Encoding.unpack bin_read_message msg.Message.payload in
      { msg with payload = Encoding.pack bin_writer_response r }
    | _ -> msg

  let msg_handler state request =
    let open Messages in
    let open Message in
    let request = Encoding.unpack bin_read_request request.payload in
    let response =
      match request with
      | Ping -> Pong
      | Get -> List !state
      | Insert s ->
        state := s :: !state;
        Success "Successfully added value to state" in
    Encoding.pack bin_writer_message (Response response)
end
