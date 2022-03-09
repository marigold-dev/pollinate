open Lwt.Infix

module Client_tests = struct
  open Bin_prot.Std
  open Pollinate

  type request =
    | Ping
    | Get
    | Insert of string
  [@@deriving bin_io, show { with_path = false }]
  type response =
    | Pong
    | List    of string list
    | Success of string
    | Error   of string
  [@@deriving bin_io, show { with_path = false }]

  type state = string list

  let msg_handler state _ request =
    let request = Util.Encoding.unpack bin_read_request request in
    let response =
      match request with
      | Ping -> Pong
      | Get -> List !state
      | Insert s ->
        state := s :: !state;
        Success "Successfully added value to state" in
    Util.Encoding.pack bin_writer_response response

  let client_a =
    Lwt_main.run @@ Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3000)
  let client_b =
    Lwt_main.run @@ Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3005)

  (* Initializes two peers and has each one request the state
     of the other, returning the first element in the response of each *)
  let trade_messages () =
    let peer_a = Client.peer_from !client_a in

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
  let test_insert () =
    let _ = Client.peer_from !client_a in

    let peer_b = Client.peer_from !client_b in

    let req = Util.Encoding.pack bin_writer_request @@ Insert "something" in

    let%lwt () = Client.send_to client_a req peer_b in
    let%lwt res_a, _ = Client.recv_next client_a in

    let res_a = Util.Encoding.unpack bin_read_response res_a in

    let res_a =
      match res_a with
      | Success resp -> show_response @@ Success resp
      | _ -> failwith "Incorrect response" in

    Lwt.return res_a
  let ping_pong () =
    let peer_b = Client.peer_from !client_b in

    let ping = Util.Encoding.pack bin_writer_request Ping in

    let%lwt () = Client.send_to client_a ping peer_b in
    let%lwt pong, _ = Client.recv_next client_a in

    let pong = Util.Encoding.unpack bin_read_response pong in

    let pong =
      match pong with
      | Pong -> show_response Pong
      | _ -> failwith "Incorrect response" in

    Lwt.return pong
end

let test_trade_messages _ () =
  Client_tests.trade_messages ()
  >|= Alcotest.(check (pair string string)) "test2 and test1" ("test2", "test1")
let test_ping_pong _ () =
  Client_tests.ping_pong () >|= Alcotest.(check string) "Ping pong" "Pong"
let test_insert_value _ () =
  Client_tests.test_insert ()
  >|= Alcotest.(check string)
        "Test insert value" "(Success \"Successfully added value to state\")"

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Client tests"
       [
         ( "communication",
           [
             Alcotest_lwt.test_case "Trading Messages" `Quick test_trade_messages;
             Alcotest_lwt.test_case "Ping pong" `Quick test_ping_pong;
             Alcotest_lwt.test_case "Insert value" `Quick test_insert_value;
           ] );
       ]
