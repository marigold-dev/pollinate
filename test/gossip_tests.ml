open Lwt.Infix
open Commons
open Pollinate
open Pollinate.PNode

module Gossip_tests = struct
  let local_address port = Address.{ address = "127.0.0.1"; port }

  (* Initializes a group of nodes connected as shown here: https://tinyurl.com/tcy8dxu8 *)
  let ( node_a,
        node_b,
        node_c,
        node_d,
        node_e,
        node_f,
        node_g,
        node_h,
        node_i,
        node_j ) =
    Lwt_main.run
      begin
        let ( addr_a,
              addr_b,
              addr_c,
              addr_d,
              addr_e,
              addr_f,
              addr_g,
              addr_h,
              addr_i,
              addr_j ) =
          ( local_address 14000,
            local_address 14001,
            local_address 14002,
            local_address 14003,
            local_address 14004,
            local_address 14005,
            local_address 14006,
            local_address 14007,
            local_address 14008,
            local_address 14009 ) in

        let%lwt node_a =
          PNode.init ~init_peers:[addr_b; addr_c; addr_e; addr_h] addr_a in
        let%lwt node_b = PNode.init ~init_peers:[addr_a; addr_d; addr_e] addr_b in
        let%lwt node_c = PNode.init ~init_peers:[addr_a; addr_f; addr_g] addr_c in
        let%lwt node_d = PNode.init ~init_peers:[addr_b] addr_d in
        let%lwt node_e = PNode.init ~init_peers:[addr_a; addr_b] addr_e in
        let%lwt node_f = PNode.init ~init_peers:[addr_c] addr_f in
        let%lwt node_g = PNode.init ~init_peers:[addr_c] addr_g in
        let%lwt node_h = PNode.init ~init_peers:[addr_a; addr_i; addr_j] addr_h in
        let%lwt node_i = PNode.init ~init_peers:[addr_h] addr_i in
        let%lwt node_j = PNode.init ~init_peers:[addr_h] addr_j in
        Lwt.return
          ( node_a,
            node_b,
            node_c,
            node_d,
            node_e,
            node_f,
            node_g,
            node_h,
            node_i,
            node_j )
      end

  let nodes =
    [
      node_a;
      node_b;
      node_c;
      node_d;
      node_e;
      node_f;
      node_g;
      node_h;
      node_i;
      node_j;
    ]

  (** Utility function for producing a list of ports from
      the addresses of the given nodes. This provides an easy
      way to identify nodes that are hosted on the same machine. *)
  let node_ports nodes =
    List.map
      (fun n ->
        let addr = Client.address_of !n in
        addr.port)
      nodes

  (** Starts the server for each node and constructs a Post message
      whose author is the specified node, then disseminates it. Checks
      every 2 seconds to see if all nodes have received the disseminated
      message. The 2 second wait occurs n times before timing out and returning
      the ports of the nodes who saw the message. *)
  let disseminate_from _n node =
    let _ =
      List.map
        (PNode.run_server ~preprocessor:Commons.preprocessor
           ~msg_handler:Commons.msg_handler)
        nodes in
    let payload =
      Client.address_of !node
      |> (fun Address.{ port; _ } -> port)
      |> string_of_int
      |> String.to_bytes in
    let message =  Client.create_post node (payload, None) in
    Client.post node message;

    let seen () =
      nodes |> List.filter (fun n -> PNode.seen n message) |> node_ports in

    let%lwt () =
      let%lwt oc =
        Lwt_io.open_file
          ~flags:[Unix.O_WRONLY; Unix.O_APPEND; Unix.O_CREAT]
          ~mode:Lwt_io.Output "/tmp/log.txt" in
      let%lwt () =
        Lwt_io.write oc (Printf.sprintf "%f\n" (Unix.gettimeofday ())) in
      Lwt_io.close oc in
    let reg_seen =
      let%lwt () = Lwt_unix.sleep 0.2 in
      Lwt.return (seen ()) in
    let f_seen =
      let%lwt () = Lwt_unix.sleep 3. in
      Lwt.return [] in
    let%lwt res = Lwt.pick [reg_seen; f_seen] in
    let%lwt () =
      let%lwt oc =
        Lwt_io.open_file
          ~flags:[Unix.O_WRONLY; Unix.O_APPEND; Unix.O_CREAT]
          ~mode:Lwt_io.Output "/tmp/log.txt" in
      let%lwt () = Lwt_io.write oc (Printf.sprintf "%d\n" (List.length res)) in
      Lwt_io.close oc in
    Lwt.return res
end

(** Test for dissemination given a specific node. *)
let test_disseminate_from node _ () =
  Gossip_tests.disseminate_from 15. node
  >|= Alcotest.(check (list int))
        (Printf.sprintf "All nodes have seen the message %d" !node.address.port)
        Gossip_tests.(node_ports nodes)

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "Gossip tests"
       [
         ( "gossip dissemination",
           [
             Alcotest_lwt.test_case "Dissemination from A" `Quick
               (test_disseminate_from Gossip_tests.node_a);
             Alcotest_lwt.test_case "Dissemination from B" `Quick
               (test_disseminate_from Gossip_tests.node_b);
             Alcotest_lwt.test_case "Dissemination from C" `Quick
               (test_disseminate_from Gossip_tests.node_c);
             Alcotest_lwt.test_case "Dissemination from D" `Quick
               (test_disseminate_from Gossip_tests.node_d);
             Alcotest_lwt.test_case "Dissemination from E" `Quick
               (test_disseminate_from Gossip_tests.node_e);
             Alcotest_lwt.test_case "Dissemination from F" `Quick
               (test_disseminate_from Gossip_tests.node_f);
             Alcotest_lwt.test_case "Dissemination from G" `Quick
               (test_disseminate_from Gossip_tests.node_g);
             Alcotest_lwt.test_case "Dissemination from H" `Quick
               (test_disseminate_from Gossip_tests.node_h);
             Alcotest_lwt.test_case "Dissemination from I" `Quick
               (test_disseminate_from Gossip_tests.node_i);
             Alcotest_lwt.test_case "Dissemination from J" `Quick
               (test_disseminate_from Gossip_tests.node_j);
           ] );
       ]
