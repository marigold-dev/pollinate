(** Peers are nodes in the network other than the user.
The built-in failure detector maintains the status of any
peer as either Alive, Suspicious, or Faulty, in order to
maintain a set of active "neighbors" to communicate with. *)

(** The status of a peer as determined and modified
by the failure detector *)
type status =
  | Alive
  | Suspicious
  | Faulty
[@@deriving show { with_path = false }, eq]

(** The type of a peer. Neighbors are represented
internally by a Base.Hashtbl, so look-ups, insertions,
and removals are all approximately constant-time. *)
type t = {
  address : Address.t;
  mutable status : status;
  mutable last_suspicious_status : Unix.tm option;
  neighbors : (Address.t, t) Base.Hashtbl.t;
}

(** Constructs a Peer.t from an Address.t. This
is the recommended way to create a Peer "from scratch". *)
val from : Address.t -> t

(** Constructs an Address.t from a Unix.sockaddr *)
val from_socket_address : Unix.sockaddr -> t

(** Adds a neighbor to the given peer's neighbors *)
val add_neighbor : t -> t -> [`Duplicate | `Ok]

(** Adds a list of neighbors to the given peer's neighbors *)
val add_neighbors : t -> t list -> [`Duplicate | `Ok] list

(** Looks up a neighbor of the given peer by address
and returns a Peer.t option containing the
neighbor if their address is found. *)
val get_neighbor : t -> Address.t -> t option
