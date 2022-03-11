type state =
  | Alive
  | Suspicious
  | Faulty

type t = {
  address : string;
  port : int;
  known_peers : t list;
  state : state;
}

let from_sockaddr sockaddr =
  let open Lwt_unix in
  match sockaddr with
  | ADDR_UNIX _ -> failwith "Unix socket addresses not supported"
  | ADDR_INET (inet, port) ->
    {
      address = Unix.string_of_inet_addr inet;
      port;
      known_peers = [];
      state = Alive;
    }

let to_sockaddr peer =
  Lwt_unix.ADDR_INET (Unix.inet_addr_of_string peer.address, peer.port)

(* Basic Knuth shuffle => https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle *)
let knuth_shuffle known_peers =
  let initial_array = Array.length (Array.of_list known_peers) in
  let shuffled_array = Array.copy (Array.of_list known_peers) in
  for i = initial_array - 1 downto 1 do
    let k = Random.int (i + 1) in
    let x = shuffled_array.(k) in
    shuffled_array.(k) <- shuffled_array.(i);
    shuffled_array.(i) <- x
  done;
  Array.to_list shuffled_array

(* Regarding the SWIM protocol, the list of peers is not ordered.
   Hence, I basically went for a shuffle after adding the new peer *)
let add_peer peer_to_add peer =
  let new_peers = peer_to_add :: peer.known_peers in
  let shuffled_list = knuth_shuffle new_peers in
  {
    address = peer.address;
    port = peer.port;
    known_peers = shuffled_list;
    state = peer.state;
  }

(* Regarding the SWIM protocol, if peer A cannot get ACK from peer B (timeout):
   A sets B as `suspicious`
   A randomly picks one (or several, should it also be randomly determined?) peer(s) from its list
   and ask him/them to ping B.*)
(* This function return the random peer, to which we will ask to ping the first peer *)
let pick_random_member peer =
  let random_int = Random.int (List.length peer.known_peers) in
  List.nth peer.known_peers random_int
