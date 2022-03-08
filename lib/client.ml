open Lwt_unix
open Util

type 'a t =
  { address: string
  ; port: int
  ; socket: file_descr
  ; state: 'a ref
  ; recv_mutex: Lwt_mutex.t
  ; state_mutex: Lwt_mutex.t
  }

let peer_from (client: 'a t) =
  Peer.{ address = client.address; port = client.port}

let send_to client payload peer =
  let len = Bytes.length payload in
  let addr = Peer.to_sockaddr peer in
  let%lwt _ = sendto !client.socket payload 0 len [] addr in
  Lwt.return ()

  (* Warning: potentially bad design
  While this function locks the receive mutex, it does
  NOT unlock it. Unlocking it would mean that _any_
  following call to recv_next would be able to read
  from the socket next. Instead, calls to read_size_of_incoming
  MUST be followed by the completion of an already initiated
  call to recv_next. *)
let read_size_of_incoming client =
  let open Lwt_unix in
  let%lwt () = Lwt_mutex.lock !client.recv_mutex in
  let size_buffer = Bytes.create 8 in
  let%lwt _ = recvfrom !client.socket size_buffer 0 8 [MSG_PEEK] in
  let len = (Encoding.read_size_header size_buffer) + 8 in
  Lwt.return len

let recv_next client =
  let%lwt msg_size = read_size_of_incoming client in
  let msg_buff = Bytes.create msg_size in
  let%lwt (_, addr) = recvfrom !client.socket msg_buff 0 msg_size [] in
  Lwt_mutex.unlock !client.recv_mutex;
  Lwt.return (msg_buff, Peer.from_sockaddr addr)

let serve client msg_handler =
  let rec server () =
    let%lwt (request, peer) = recv_next client in
    let%lwt () = Lwt_mutex.lock !client.state_mutex in
    let response = msg_handler !client.state peer request in
    let%lwt () = send_to client response peer in
    Lwt_mutex.unlock !client.state_mutex;
    server () in
  Lwt.async server

let init ~state ~msg_handler (address, port) =
  let%lwt socket = Net.create_socket port in
  let state = ref state in
  let recv_mutex = Lwt_mutex.create () in
  let state_mutex = Lwt_mutex.create () in
  let client = ref { address; port; socket ; state ; recv_mutex ; state_mutex } in
  serve client msg_handler;
  Lwt.return client