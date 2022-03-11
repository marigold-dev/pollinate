open Lwt.Infix

module Commons = struct
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
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3000))

  let client_b =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3005))

  let peer_a = Client.peer_from !client_a

  let peer_b = Client.peer_from !client_b
  let client_c =
    Lwt_main.run (Client.init ~state:["test1"] ~msg_handler ("127.0.0.1", 3001))

  let client_d =
    Lwt_main.run (Client.init ~state:["test2"] ~msg_handler ("127.0.0.1", 3006))

  let peer_c = Client.peer_from !client_c

  let peer_d = Client.peer_from !client_d
end

module Client_tests = struct
  open Pollinate

  (* Initializes two peers and has each one request the state
     of the other, returning the first element in the response of each *)
  let trade_messages () =
    let open Commons in
    let get = Util.Encoding.pack bin_writer_request Get in

    let%lwt () = Client.send_to client_a get peer_b in
    let%lwt res_a, _ = Client.recv_next client_a in

    let res_a = Util.Encoding.unpack bin_read_response res_a in

    let%lwt () = Client.send_to client_b get peer_a in
    let%lwt res_b, _ = Client.recv_next client_b in

    let res_b = Util.Encoding.unpack bin_read_response res_b in

    let res_a, res_b =
      match (res_a, res_b) with
      | List l1, List l2 -> (List.hd l1, List.hd l2)
      | _ -> failwith "Incorrect response" in

    Lwt.return (res_a, res_b)

  let test_insert () =
    let open Commons in
    let req = Util.Encoding.pack bin_writer_request (Insert "something") in

    let%lwt () = Client.send_to client_a req peer_b in
    let%lwt res_a, _ = Client.recv_next client_a in

    let res_a = Util.Encoding.unpack bin_read_response res_a in

    let get = Util.Encoding.pack bin_writer_request Get in

    let%lwt () = Client.send_to client_a get peer_b in
    let%lwt status_of_b, _ = Client.recv_next client_a in

    let status_of_b = Util.Encoding.unpack bin_read_response status_of_b in

    let res_a, status_of_b =
      match (res_a, status_of_b) with
      | Success resp, List lb -> (show_response (Success resp), List.hd lb)
      | _ -> failwith "Incorrect response" in

    Lwt.return (res_a, status_of_b)

  let ping_pong () =
    let open Commons in
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

module Peer_tests = struct
  open Pollinate
  let add_peer_test () =
    let open Commons in
    let peer = Peer.add_peer peer_a peer_b in
    Lwt.return @@ List.length peer.known_peers

  let knuth_shuffle_test () =
    let open Commons in
    let peer_a = Peer.add_peer peer_b peer_a in
    let peer_a = Peer.add_peer peer_c peer_a in
    let peer_a = Peer.knuth_shuffle peer_a.known_peers in
    Lwt.return @@ List.length peer_a
end

let test_trade_messages _ () =
  Client_tests.trade_messages ()
  >|= Alcotest.(check (pair string string)) "test2 and test1" ("test2", "test1")

let test_ping_pong _ () =
  Client_tests.ping_pong () >|= Alcotest.(check string) "Ping pong" "Pong"

let test_insert_value _ () =
  Client_tests.test_insert ()
  >|= Alcotest.(check (pair string string))
        "Test insert value"
        (Commons.show_response Commons.Pong, "something")

let test_add_peer _ () =
  Peer_tests.add_peer_test ()
  >|= Alcotest.(check int)
        "When adding peer to an empty list of know_peers, length is 1" 1

let test_knuth_shuffle _ () =
  Peer_tests.knuth_shuffle_test ()
  >|= Alcotest.(check int) "Knuth_shuffle does not change length of list" 2

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
         ( "peer",
           [
             Alcotest_lwt.test_case "Add peer" `Quick test_add_peer;
             Alcotest_lwt.test_case "Knuth shuffle" `Quick test_knuth_shuffle;
           ] );
       ]
