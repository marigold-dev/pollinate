open Lwt_unix
open Util

(** Configurable parameters that affect various aspects of the failure
detector *)
type failure_detector_config = {
  (* The period of time within which peers may be randomly chosen
     to be pinged, and within which any peer who has been pinged must
     respond with an acknowledgement message to continue being considered
     alive to other nodes in the network. The protocol period should
     be at least three times the round_trip_time. *)
  protocol_period : int;
  (* TODO: Implement automatic configuration/empirical determination of an ideal round-trip time *)
  (* The amount of time a node performing a random-probe of a
     peer will wait before asking other active peers to probe the
     same peer. This value must be at most a third of the protocol period,
     but it is best if it is chosen empirically. *)
  round_trip_time : int;
  (* The size of 'failure detection subgroups'. In other words, the
     number of peers that will be asked to ping a suspicious node which
     has failed to respond with acknowledgement during the round_trip_time. *)
  helpers_size : int;
}

(** The state of a failure detection component. *)
type failure_detector = {
  config : failure_detector_config;
  (* Table mapping sequence numbers to condition variables that get
      signalled when a peer that was probed during the period to which
      the sequence number applies replies with acknowledgement. *)
  acknowledges : (int, unit Lwt_condition.t) Base.Hashtbl.t;
  mutable sequence_number : int;
}

type 'a t = {
  address : Address.t;
  (* An ID that is incremented whenever a request is
     made from this client. The response matching this
     request will carry the same ID, allowing the response
     to be identified and thus stopping the request from
     blocking. *)
  current_request_id : int ref Mutex.t;
  (* A hashtable that pairs request IDs with condition variables.
     When a response is received by the server, it checks this table
     for a waiting request and signals the request's condition variable
     with the incoming response. *)
  request_table : (int, Message.t Lwt_condition.t) Hashtbl.t;
  socket : file_descr Mutex.t;
  state : 'a ref Mutex.t;
  (* A store of incoming messages for the client. Stores
     messages separately by category. *)
  inbox : Inbox.t;
  failure_detector : failure_detector;
  peers : (Address.t, Peer.t) Base.Hashtbl.t;
}

let address_of { address; _ } = address

let peer_from { address; peers; _ } =
  Peer.{ address; status = Alive; neighbors = peers }

let create_request client recipient payload =
  Mutex.with_lock !client.current_request_id (fun id ->
      id := !id + 1;
      Lwt.return
        Message.
          {
            category = Message.Request;
            id = !id;
            sender = !client.address;
            recipient;
            payload;
          })

let create_response client request payload =
  Message.
    {
      category = Message.Response;
      id = request.id;
      sender = !client.address;
      recipient = request.sender;
      payload;
    }

let send_to client message =
  let open Message in
  let payload = Encoding.pack Message.bin_writer_t message in
  let len = Bytes.length payload in
  let addr = Address.to_sockaddr message.recipient in
  Mutex.unsafe !client.socket (fun socket ->
      let%lwt _ = sendto socket payload 0 len [] addr in
      Lwt.return ())

let recv_next client =
  let open Lwt_unix in
  let open Util in
  (* Peek the first 8 bytes of the incoming datagram
     to read the Bin_prot size header. *)
  let size_buffer = Bytes.create Encoding.size_header_length in
  let%lwt client_socket = Mutex.lock !client.socket in
  (* Flag MSG_PEEK means: peeks at an incoming message.
     The data is treated as unread and the next recvfrom()
     or similar function shall still return this data.
     Here, we only need the mg_size.
  *)
  let%lwt _ =
    recvfrom client_socket size_buffer 0 Encoding.size_header_length [MSG_PEEK]
  in
  let msg_size =
    Encoding.read_size_header size_buffer + Encoding.size_header_length in
  let msg_buffer = Bytes.create msg_size in
  (* Now that we have read the header and the message size, we can read the message *)
  let%lwt _ = recvfrom client_socket msg_buffer 0 msg_size [] in
  let message = Encoding.unpack Message.bin_read_t msg_buffer in
  Mutex.unlock !client.socket;
  Lwt.return message

let request client request recipient =
  let%lwt message = create_request client recipient request in
  let%lwt () = send_to client message in
  let condition_var = Lwt_condition.create () in
  Hashtbl.add !client.request_table message.id condition_var;
  Lwt_condition.wait condition_var

let broadcast_request client req recipients =
  List.map (request client req) recipients

let route client router msg =
  let open Message in
  let msg = router msg in
  Inbox.push !client.inbox msg.category msg

module Failure_detector = struct
  (** Messages sent by the failure detector protocol *)
  type message =
    | Ping
    | Acknowledge
    | PingRequest of Address.t
  [@@deriving bin_io]

  (** Initializes the failure detection component
  with a default state and given config *)
  let make config =
    { config; acknowledges = Base.Hashtbl.Poly.create (); sequence_number = 0 }

  (* Helper to increase the round *)
  let next_seq_no t =
    let sequence_number = t.sequence_number in
    t.sequence_number <- t.sequence_number + 1;
    sequence_number

  let wait_ack t sequence_number =
    let cond =
      Base.Hashtbl.find_or_add t.acknowledges sequence_number
        ~default:Lwt_condition.create in
    Lwt_condition.wait cond

  let wait_ack_timeout t sequence_number timeout =
    Lwt.pick
      [
        (let _ = Lwt_unix.sleep (Float.of_int timeout) in
         Lwt.return @@ Result.Error "Timeout reached");
        (let _ = wait_ack t sequence_number in
         Lwt.return @@ Result.Ok "Successfully received acknowledge");
      ]

  (** Basic random shuffle, see https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle*)
  let knuth_shuffle known_peers =
    let shuffled_array = Array.copy (Array.of_list known_peers) in
    let initial_array_length = Array.length shuffled_array in
    for i = initial_array_length - 1 downto 1 do
      let k = Random.int (i + 1) in
      let x = shuffled_array.(k) in
      shuffled_array.(k) <- shuffled_array.(i);
      shuffled_array.(i) <- x
    done;
    Array.to_list shuffled_array

  (* Regarding the SWIM protocol, if peer A cannot get ACK from peer B (timeout):
     A sets B as `suspicious`
     A randomly picks one (or several, should it also be randomly determined?) peer(s) from its list
     and ask him/them to ping B.*)
  (* This function return the random peer, to which we will ask to ping the first peer *)
  let rec pick_random_neighbors neighbors number_of_neighbors =
    let addresses = neighbors |> Base.Hashtbl.keys |> knuth_shuffle in
    match addresses with
    | [] -> failwith "pick_random_peers"
    | elem :: _ ->
      if number_of_neighbors = 1 then
        [elem]
      else
        elem :: pick_random_neighbors neighbors (number_of_neighbors - 1)

  let update_neighbor_status peer neighbor status =
    let open Peer in
    let local_neighbor = get_neighbor peer neighbor.address in
    match local_neighbor with
    | Some neighbor ->
      neighbor.status <- status;
      Base.Hashtbl.update peer.neighbors neighbor.address ~f:(fun _ -> neighbor)
    | None -> ()
  let create_message client message (recipient : Peer.t) =
    Message.
      {
        category = Failure_detection;
        id = -1;
        sender = address_of !client;
        recipient = recipient.address;
        payload = Util.Encoding.pack bin_writer_message message;
      }

  let send_message message client (recipient : Peer.t) =
    let message = create_message client message recipient in
    send_to client message

  let send_ping_to client peer = send_message Ping client peer

  let send_acknowledge_to client peer = send_message Acknowledge client peer

  let send_ping_request_to client (recipient : Peer.t) =
    send_message (PingRequest recipient.address) client recipient

  (** Processes an incoming message bound for the failure detector of a client *)
  let handle_message client message =
    let open Message in
    let peer_of_client = peer_from !client in
    let peer = Peer.from message.sender in
    let msg = Util.Encoding.unpack bin_read_message message.payload in
    let t = !client.failure_detector in
    match msg with
    | Ping -> send_acknowledge_to client peer
    | PingRequest addr -> (
      let new_seq_no = next_seq_no t in
      let peer_opt = Peer.get_neighbor peer_of_client addr in
      match peer_opt with
      | Some peer -> send_ping_request_to client peer
      | None -> (
        match%lwt wait_ack_timeout t new_seq_no t.config.protocol_period with
        | Ok _ -> Lwt.return ()
        | Error _ -> send_acknowledge_to client peer))
    | Acknowledge ->
    match Base.Hashtbl.find t.acknowledges t.sequence_number with
    | Some cond ->
      Lwt_condition.broadcast cond ();
      Lwt.return ()
    | None -> Lwt.return ()

  (** This function will be called by failure_detection 
  at each round of the protocol, and update the peers *)
  let probe_peer t client peer_to_update =
    let peer_of_client = peer_from !client in
    let new_seq_no = next_seq_no t in
    let _ = send_ping_to client peer_to_update in
    match%lwt wait_ack_timeout t new_seq_no t.config.round_trip_time with
    | Ok _ -> Lwt.return ()
    | Error _ -> (
      let pingers =
        t.config.helpers_size
        |> pick_random_neighbors peer_of_client.neighbors
        |> List.map Peer.from in
      let _ = List.map (send_ping_request_to client) pingers in
      let wait_time = t.config.protocol_period - t.config.round_trip_time in
      match%lwt wait_ack_timeout t new_seq_no wait_time with
      | Ok _ -> Lwt.return ()
      | Error _ ->
        (* TODO: Implement Suspicion Mechanism.
           This is correct in the basic SWIM protocol, but it is a very heavy penalty.
           When there is no ACK (direct or indirect) the peer must be set to `Suspicious`.
           See section 4.2 from https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf *)
        let _ = update_neighbor_status peer_of_client peer_to_update Faulty in
        Lwt.return ())

  (** High level function, which must be run within an async thread, like:
  Lwt.async (fun () -> failure_detection t client); *)
  let failure_detection client =
    let open Peer in
    let t = !client.failure_detector in
    let available_peers =
      List.filter
        (fun p -> p.status = Peer.Alive)
        (Base.Hashtbl.data !client.peers) in
    match List.length available_peers with
    | 0 -> Lwt.return ()
    | _ ->
      let random_peer =
        List.map (fun p -> p.address) available_peers
        |> knuth_shuffle
        |> List.hd in
      let _ =
        Lwt.join
          [
            probe_peer t client (Peer.from random_peer);
            Lwt_unix.sleep @@ Float.of_int t.config.protocol_period;
          ] in
      Lwt.return ()
end

(* Signals a waiting request with its corresponding response
   if it exists. Otherwise returns None. *)
let handle_response request_table res =
  let open Message in
  let* res in
  let* waiting_request = Hashtbl.find_opt request_table res.id in
  Some (Lwt_condition.signal waiting_request res)

(* Sever procedure:
   1. Receive the next incoming message
   2. Route the message
   3. Grab the next response if it exists and send it to the request waiting for it
   4. Grab the next request if it exists and send it to the message handler along with the
     client's state
   5. Send the encoded response from the message handler to the requester *)
let serve client router msg_handler =
  let rec server () =
    let%lwt message = recv_next client in
    let%lwt () = route client router message in

    let%lwt () =
      match%lwt Inbox.next !client.inbox Message.Failure_detection with
      | Some message -> Failure_detector.handle_message client message
      | None -> Lwt.return () in

    let%lwt () = Failure_detector.failure_detection client in

    let%lwt next_response = Inbox.next !client.inbox Message.Response in
    let _ = handle_response !client.request_table next_response in

    let%lwt request = Inbox.next !client.inbox Message.Request in
    let%lwt () =
      match request with
      | Some request ->
        let%lwt state = Mutex.lock !client.state in
        let response =
          request |> msg_handler state |> create_response client request in
        let%lwt () = send_to client response in
        Lwt.return (Mutex.unlock !client.state)
      | None -> Lwt.return () in

    server () in
  Lwt.async server

let init ~state ?(router = fun m -> m) ~msg_handler ?(init_peers = [])
    (address, port) =
  let open Util in
  let%lwt socket = Net.create_socket port in
  let socket = Mutex.create socket in
  let peers =
    Base.Hashtbl.create ~growth_allowed:true ~size:0 (module Address) in
  let _ =
    init_peers
    |> List.map (fun addr ->
          Base.Hashtbl.add peers ~key:addr ~data:(Peer.from addr)) in
  let client =
    ref
      {
        address = Address.create address port;
        current_request_id = Mutex.create (ref 0) ;
        request_table = Hashtbl.create 20;
        socket;
        state = Mutex.create (ref state);
        inbox = Inbox.create ();
        failure_detector =
        Failure_detector.make
        { protocol_period = 9; round_trip_time = 3; helpers_size = 3 };
        peers
      } in
  serve client router msg_handler;
  Lwt.return client
