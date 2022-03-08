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

let recv_next client =
  let open Lwt_unix in
  (* Peek at the first 8 bytes of the incoming datagram
  to read the Bin_prot size header. *)
  let size_buffer = Bytes.create 8 in
  let%lwt () = Lwt_mutex.lock !client.recv_mutex in
  let%lwt _ = recvfrom !client.socket size_buffer 0 8 [MSG_PEEK] in
  let msg_size = (Encoding.read_size_header size_buffer) + 8 in
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