open Lwt.Infix
open Pollinate
open Messages

module Client_tests = struct
  type state = string list

  let protocol : Failure_detector.t =
    let config =
      Failure_detector.
        { protocol_period = 5; round_trip_time = 2; peers_to_ping = 1 } in
    Failure_detector.make config

  let msg_handler state _ request =
    let open Messages in
    let request = Util.Encoding.unpack bin_read_request request in
    let response =
      match request with
      | Ping -> Pong
      | Get -> List !state
      | Insert s ->
        state := s :: !state;
        Success "Successfully added value to state" in
    Util.Encoding.pack bin_writer_response response

  (* Initializes four clients and the related four peers *)
  let client_a =
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3000))
  let peer_a = Peer.from (Client.address_of !client_a)

  let client_b =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3001))
  let peer_b = Peer.from (Client.address_of !client_b)

  let client_c =
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3002))
  let peer_c = Peer.from (Client.address_of !client_c)

  let client_d =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3003))
  let peer_d = Peer.from (Client.address_of !client_d)

  (* Initializes two peers and has each one request the state
     of the other, returning the first element in the response of each *)
  let trade_messages () =
    let open Messages in
    let get = Util.Encoding.pack bin_writer_request Get in

    let%lwt { payload = res_from_b; _ } =
      Client.request client_a get peer_b.address in
    let res_from_b = Encoding.unpack bin_read_response res_from_b in

    let%lwt { payload = res_from_a; _ } =
      Client.request client_b get peer_a.address in
    let res_from_a = Encoding.unpack bin_read_response res_from_a in

    let res_from_b, res_from_a =
      match (res_from_b, res_from_a) with
      | List l1, List l2 -> (List.hd l1, List.hd l2)
      | _ -> failwith "Incorrect response" in

    Lwt.return (res_from_b, res_from_a)

  let test_insert () =
    let open Messages in
    let req = Util.Encoding.pack bin_writer_request (Insert "something") in

    let%lwt () = Client.send_to client_a req peer_b in
    let%lwt res_a, _ = Client.recv_next client_a in

    let res_a = Util.Encoding.unpack bin_read_response res_a in

    let%lwt { payload = res_a; _ } =
      Client.request client_a insert_req peer_b.address in
    let res_a = Encoding.unpack bin_read_response res_a in

    let get = Encoding.pack bin_writer_message (Request Get) in
    let%lwt { payload = b_state; _ } =
      Client.request client_a get peer_b.address in
    let b_state = Encoding.unpack bin_read_response b_state in

    let res_a, b_state =
      match (res_a, b_state) with
      | Success _, List lb -> ("Success", List.hd lb)
      | _ -> failwith "Incorrect response" in

    Lwt.return (res_a, b_state)

  let ping_pong () =
    let open Messages in
    let ping = Util.Encoding.pack bin_writer_request Ping in

    let%lwt () = Client.send_to client_a ping peer_b in
    let%lwt pong, _ = Client.recv_next client_a in

    let%lwt { payload = pong; _ } =
      Client.request client_a ping peer_b.address in
    let pong = Encoding.unpack bin_read_response pong in

    let pong =
      match pong with
      | Pong -> show_response Pong
      | _ ->
        failwith (Printf.sprintf "Incorrect response: %s" (show_response pong))
    in

    Lwt.return pong
end

let test_trade_messages _ () =
  Client_tests.trade_messages ()
  >|= Alcotest.(check (pair string string)) "test2 and test1" ("test2", "test1")

let test_ping_pong _ () =
  Client_tests.ping_pong () >|= Alcotest.(check string) "Ping pong" "Pong"

let test_insert_value _ () =
  let open Messages in
  Client_tests.test_insert ()
  >|= Alcotest.(check (pair string string))
        "Test insert value" ("Success", "something")

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Client tests"
       [
         ( "communication",
           [
             Alcotest_lwt.test_case "Trading Messages" `Quick test_trade_messages;
             Alcotest_lwt.test_case "Ping pong" `Quick test_ping_pong;
           ] );
       ]
