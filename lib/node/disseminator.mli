(** Component responsible for gossip-style dissemination of
    messages across the network *)

(** A record containing information and state relevant to the
    dissemination component. *)
type t

(** Creates a dissemination component that can be attached to a node
    when given the number of "rounds" for which each new message should
    be disseminated and an "epoch length", in seconds, which determines
    whether a message is too old to be disseminated again by checking
    whether the message is newer than n seconds old, where n is the
    given epoch length. *)
val create : num_rounds:int -> epoch_length:float -> t

(** Starts the next round of dissemination, affecting the state
    of the disseminator. In particular, this function causes the
    current round to increase, reduces the number of rounds remaining
    for each message being disseminated, and filters out messages with
    no rounds remaining or a timestamp that's older than epoch_length
    seconds. *)
val next_round : t -> t

(** Adds a new message to the dissemination pool. The message will not be
    posted if it is older than the epoch_length. Otherwise, the message
    will begin to be disseminated automatically as long as the disseminator
    is running along with Networking.disseminate.*)
val post : t -> Message.t -> t

(** Returns the list of messages that need to be disseminated. For
    exclusive use by Networking.disseminate. *)
val broadcast_queue : t -> Message.t list

(** Determines whether the dissemination component has witnessed a
    given message before, or whether the message is too old to be
    retained in the set of seen messages. *)
val seen : t -> Message.t -> bool

(** Returns the 7 digit hashes of all the messages
    that the disseminator has seen. *)
val all_seen : t -> string list

(** Returns the current disseminator round. *)
val current_round : t -> int
