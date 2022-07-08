(** Utils function shared by the different tests modules *)
module Commons = struct
  open Pollinate.PNode
  open Pollinate.Util
  open Messages
  open Message

  let preprocessor msg =
    let open Messages in
    match msg.Message.pollinate_category with
    | Request ->
      let[@warning "-8"] (Request r) =
        Encoding.unpack bin_read_message msg.Message.payload.data in
      {
        msg with
        payload =
          { data = Encoding.pack bin_writer_request r; signature = None };
      }
    | Response ->
      let[@warning "-8"] (Response r) =
        Encoding.unpack bin_read_message msg.Message.payload.data in
      {
        msg with
        payload =
          { data = Encoding.pack bin_writer_response r; signature = None };
      }
    | _ -> msg

  let msg_handler message =
    let open Messages in
    match message.pollinate_category with
    | Request ->
      let request = Encoding.unpack bin_read_request message.payload.data in
      let response =
        match request with
        | Ping -> Pong
        | Get -> Pong
        | Insert _ -> Success "Successfully added value to state" in
      let msg =
        Message.
          {
            data = Response response |> Encoding.pack bin_writer_message;
            signature = None;
          } in
      Some msg
    | Post -> None
    | _ -> failwith "unhandled in tests"
end
