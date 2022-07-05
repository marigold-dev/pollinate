open Lwt.Infix
open Commons
open Pollinate
open Pollinate.PNode
open Pollinate.Util
open Messages

module Node_tests = struct
  (* Initializes two nodes and the related two peers *)
  let node_a =
    Lwt_main.run (Node.init Address.{ address = "127.0.0.1"; port = 3000 })

  let peer_a = Client.peer_from !node_a

  let node_b =
    Lwt_main.run (Node.init Address.{ address = "127.0.0.1"; port = 3001 })

  let peer_b = Client.peer_from !node_b

  (* Initializes two peers and has each one request the state
     of the other, returning the first element in the response of each *)
  let trade_messages () =
    let open Messages in
    let _ =
      Lwt_list.map_p
        (Node.run_server ~preprocessor:Commons.preprocessor
           ~msg_handler:Commons.msg_handler)
        [node_a; node_b] in
    let get = Encoding.pack bin_writer_message (Request Get) in

    let%lwt { payload = res_from_b; _ } =
      Client.request node_a (get, None) peer_b.address in
    let res_from_b = Encoding.unpack bin_read_response res_from_b in

    let%lwt { payload = res_from_a; _ } =
      Client.request node_b (get, None) peer_a.address in
    let res_from_a = Encoding.unpack bin_read_response res_from_a in

    let res_from_b, res_from_a =
      match (res_from_b, res_from_a) with
      | Pong, Pong -> ("Ok", "Ok")
      | _ -> failwith "Incorrect response" in

    Lwt.return (res_from_b, res_from_a)

  let ping_pong () =
    let open Messages in
    let _ =
      Lwt_list.map_p
        (Node.run_server ~preprocessor:Commons.preprocessor
           ~msg_handler:Commons.msg_handler)
        [node_a; node_b] in
    let ping = Encoding.pack bin_writer_message (Request Ping) in

    let%lwt { payload = pong; _ } =
      Client.request node_a (ping, None) peer_b.address in
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

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Client tests"
       [
         ( "one-to-one communication",
           [
             Alcotest_lwt.test_case "Trading Messages" `Quick test_trade_messages;
             Alcotest_lwt.test_case "Ping pong" `Quick test_ping_pong;
           ] );
       ]
