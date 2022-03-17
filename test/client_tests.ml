open Lwt.Infix
open Pollinate
open Commons

module Client_tests = struct
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

let test_trade_messages _ () =
  Client_tests.trade_messages ()
  >|= Alcotest.(check (pair string string)) "test2 and test1" ("test2", "test1")

let test_ping_pong _ () =
  Client_tests.ping_pong () >|= Alcotest.(check string) "Ping pong" "Pong"

let test_insert_value _ () =
  let open Commons in
  Client_tests.test_insert ()
  >|= Alcotest.(check (pair string string))
        "Test insert value"
        (show_response Pong, "something")

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Client tests"
       [
         ( "communication",
           [
             Alcotest_lwt.test_case "Trading Messages" `Quick test_trade_messages;
             Alcotest_lwt.test_case "Ping pong" `Quick test_ping_pong
             (* Alcotest_lwt.test_case "Insert value" `Quick test_insert_value; *);
           ] );
       ]
