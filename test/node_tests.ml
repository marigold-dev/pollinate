open Lwt.Infix
open Pollinate.PNode
open Pollinate.Util
open Commons
open Messages

module Node_tests = struct
  (* Initializes two nodes and the related two peers *)
  let node_a =
    Lwt_main.run
      (Pnode.init ~preprocess:Commons.preprocess
         ~msg_handler:Commons.msg_handler ("127.0.0.1", 3000))

  let peer_a = Client.peer_from !node_a

  let node_b =
    Lwt_main.run
      (Pnode.init ~preprocess:Commons.preprocess
         ~msg_handler:Commons.msg_handler ("127.0.0.1", 3001))

  let peer_b = Client.peer_from !node_b

  (* Initializes two peers and has each one request the state
     of the other, returning the first element in the response of each *)
  let trade_messages () =
    let open Messages in
    let get = (Encoding.pack bin_writer_message (Request Get), None) in
    let%lwt { payload = res_from_b; _ } =
      Client.request node_a get peer_b.address in
    let res_from_b = Encoding.unpack bin_read_response res_from_b in
    let%lwt { payload = res_from_a; _ } =
      Client.request node_b get peer_a.address in
    let res_from_a = Encoding.unpack bin_read_response res_from_a in
    let res_from_b, res_from_a =
      match (res_from_b, res_from_a) with
      | Success ok1, Success ok2 -> (ok1, ok2)
      | _ -> failwith "Incorrect response" in
    Lwt.return (res_from_b, res_from_a)

  let test_insert () =
    let open Messages in
    let insert_req =
      (Encoding.pack bin_writer_message (Request (Insert "something")), None)
    in
    let%lwt { payload = res_a; _ } =
      Client.request node_a insert_req peer_b.address in
    let res_a = Encoding.unpack bin_read_response res_a in
    let get = (Encoding.pack bin_writer_message (Request Get), None) in
    let%lwt { payload = b_state; _ } =
      Client.request node_a get peer_b.address in
    let b_state = Encoding.unpack bin_read_response b_state in
    let res_a, b_state =
      match (res_a, b_state) with
      | Success ok1, Success ok2 -> (ok1, ok2)
      | _ -> failwith "Incorrect response" in
    Lwt.return (res_a, b_state)

  let ping_pong () =
    let open Messages in
    let ping = (Encoding.pack bin_writer_message (Request Ping), None) in
    let%lwt { payload = pong; _ } = Client.request node_a ping peer_b.address in
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
  Node_tests.trade_messages ()
  >|= Alcotest.(check (pair string string)) "test2 and test1" ("Ok", "Ok")

let test_ping_pong _ () =
  Node_tests.ping_pong () >|= Alcotest.(check string) "Ping pong" "Pong"

let test_insert_value _ () =
  Node_tests.test_insert ()
  >|= Alcotest.(check (pair string string))
        "Test insert value"
        ("Successfully added value to state", "Ok")

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
