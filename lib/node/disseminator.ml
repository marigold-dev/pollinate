type pool_elt = {
  message : Message.t;
  remaining : int;
}

(** Set of md5 message hashes in hex-string form
    for storing "seen" messages *)
module DigestSet = Set.Make (Digest)

type t = {
  round : int;
  pool : pool_elt list;
  num_rounds : int;
  epoch_length : float;
  seen : DigestSet.t;
}

let create ~num_rounds ~epoch_length =
  { round = 0; pool = []; num_rounds; epoch_length; seen = DigestSet.empty }

(* Increments disseminator.round and decrements pool_elt.remaining for
   each disseminator pool element. Removes messages from the pool
   that have been disseminated num_rounds times or which are
   older than the epoch length.*)
let next_round disseminator =
  let round = disseminator.round + 1 in
  let pool =
    disseminator.pool
    |> List.map (fun ({ remaining; _ } as elt) ->
           { elt with remaining = remaining - 1 })
    |> List.filter (fun elt ->
           elt.remaining > 0
           && elt.message.timestamp > Unix.time () -. disseminator.epoch_length)
  in

  { disseminator with round; pool }

let post disseminator message =
  let open Message in
  let time = Unix.time () in
  if message.timestamp > time -. disseminator.epoch_length then
    let pool =
      { message; remaining = disseminator.num_rounds } :: disseminator.pool
    in
    let digest_of_post = Message.hash_of message in
    let seen = DigestSet.add digest_of_post disseminator.seen in
    { disseminator with pool; seen }
  else
    disseminator

let broadcast_queue disseminator =
  List.map (fun e -> e.message) disseminator.pool

let seen disseminator message =
  let open Message in
  let time = Unix.time () in
  if message.timestamp > time -. disseminator.epoch_length then
    let hash = Message.hash_of message in
    DigestSet.mem hash disseminator.seen
  else
    false

let get_seen_messages disseminator = disseminator.seen |> DigestSet.to_seq |> List.of_seq

let current_round { round; _ } = round
