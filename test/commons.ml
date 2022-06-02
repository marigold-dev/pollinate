(** Utils function shared by the different tests modules *)
module Commons = struct
  open Pollinate.PNode
  open Pollinate.Util
  open Messages

  let preprocessor msg =
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

  let msg_handler message =
    let open Messages in
    let open Message in
    match message.category with
    | Request ->
      let request = Encoding.unpack bin_read_request message.payload in
      let response =
        match request with
        | Ping -> Pong
        | Get -> Pong
        | Insert _ -> Success "Successfully added value to state" in
      ( Response response |> Encoding.pack bin_writer_message |> Option.some,
        None )
    | _ -> (None, None)
end
