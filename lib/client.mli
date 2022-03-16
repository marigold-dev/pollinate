(** Types and functions pertaining to clients in a P2P application *)

(** Clients are defined by a UDP socket bound
to an address and port, a reference to some state
whose type is user-defined, a mutex that gets
locked whenever the client's socket is being used to
receive a message (sending is non-blocking), or when the
state is being read from or written to by the server. *)
type 'a t

(** Constructs a Peer.t from an 'a Client.t*)
val peer_from : Address.t -> Peer.t

(** Sends a serialized payload via datagram from the given client
to a specified peer *)
val send_to : 'a t ref -> bytes -> Peer.t -> unit Lwt.t

(** Sends a serialized payload via datagram from the given client
to the specified peers *)
val naive_broadcast : 'a t ref -> bytes -> Peer.t list -> unit Lwt.t

(** Waits for the next incoming datagram and returns the
serialized payload along with the peer who sent the datagram *)
val recv_next : 'a t ref -> (bytes * Address.t) Lwt.t

(** Initializes the client with an initial state and a message
handler that acts on the current state, the peer sending the message,
and the message itself in bytes. The message handler is used
to initialize a server that runs asynchronously. Returns
a reference to the client. *)
val init :
  state:'a ->
  msg_handler:('a ref -> Address.t -> bytes -> bytes) ->
  string * int ->
  'a t ref Lwt.t

val address_of : 'a t -> Address.t