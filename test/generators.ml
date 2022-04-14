open Messages
open QCheck2.Gen
open Pollinate
let address_gen =
  pair (pure "127.0.0.1") int >|= fun (address, port) ->
  Address.{ address; port }

let peer_gen =
  let open Peer in
  address_gen >|= fun address ->
  {
    address;
    status = Alive;
    neighbors = Base.Hashtbl.Poly.create ();
    last_suspicious_status = None;
  }

let request_gen =
  let open Messages in
  let* str = string_printable in
  oneofl [Get; Ping; Insert str]

let peer_status_gen =
  let open Peer in
  oneofl [Alive; Suspicious; Faulty]

let sockaddress_gen =
  let* num1 = numeral in
  let* num2 = numeral in
  let* num3 = numeral in
  let* num4 = numeral in
  let addr =
    String.concat "."
      [
        Char.escaped num1;
        Char.escaped num2;
        Char.escaped num3;
        Char.escaped num4;
      ] in
  pair (pure addr) int >|= fun (address, port) ->
  Unix.ADDR_INET (Unix.inet_addr_of_string address, port)
