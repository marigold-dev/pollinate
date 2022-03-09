open Lwt.Infix

module Client_tests = struct
  open Bin_prot.Std
  open Pollinate

  type request =
    | Get
    | Insert of string
  [@@deriving bin_io]
  type response =
    | List    of string list
    | Success of string
    | Error   of string
  [@@deriving bin_io]

  type state = string list

  let msg_handler state _ request =
    let request = Util.Encoding.unpack bin_read_request request in
    let response =
      match request with
      | Get -> List !state
      | Insert s ->
        state := s :: !state;
        Success "Successfully added value to state" in
    Util.Encoding.pack bin_writer_response response

  (* Initializes two peers and has each one request the state
     of the other, returning the first element in the response of each *)
  let trade_messages () =
    let%lwt client_a =
      Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3000) in
    let peer_a = Client.peer_from !client_a in

    let%lwt client_b =
      Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3005) in
    let peer_b = Client.peer_from !client_b in

    let req = Util.Encoding.pack bin_writer_request Get in

    let%lwt () = Client.send_to client_a req peer_b in
    let%lwt res_a, _ = Client.recv_next client_a in

    let res_a = Util.Encoding.unpack bin_read_response res_a in

    let%lwt () = Client.send_to client_b req peer_a in
    let%lwt res_b, _ = Client.recv_next client_b in

    let res_b = Util.Encoding.unpack bin_read_response res_b in

    let res_a, res_b =
      match (res_a, res_b) with
      | List l1, List l2 -> (List.hd l1, List.hd l2)
      | _ -> failwith "Incorrect response" in

    Lwt.return (res_a, res_b)
end

let test_trade_messages _ () =
  Client_tests.trade_messages ()
  >|= Alcotest.(check (pair string string)) "test2 and test1" ("test2", "test1")

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Client tests"
       [
         ( "communication",
           [
             Alcotest_lwt.test_case "Trading Messages" `Quick test_trade_messages;
           ] );
       ]
