(** Utils function shared by the different tests modules *)
module Commons = struct
  open Bin_prot.Std
  open Pollinate.Node
  open Pollinate.Util
  open Messages
  
  
  type state = string list
  
  let router msg =
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

  (* Initializes four nodes and the related four peers *)
  let node_a =
    Lwt_main.run
      (Node.init ~router ~state:["test1"] ~msg_handler ("127.0.0.1", 3000))

  let peer_a = Client.peer_from !node_a

  let node_b =
    Lwt_main.run
      (Node.init ~router ~state:["test2"] ~msg_handler ("127.0.0.1", 3001))

  let peer_b = Client.peer_from !node_b

  let node_c =
    Lwt_main.run
      (Node.init ~router ~state:["test1"] ~msg_handler ("127.0.0.1", 3002))

  let peer_c = Client.peer_from !node_c

  let node_d =
    Lwt_main.run
      (Node.init ~router ~state:["test2"] ~msg_handler ("127.0.0.1", 3003))

  let peer_d = Client.peer_from !node_d
end
