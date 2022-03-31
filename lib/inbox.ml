type t = (Message.category, Message.t Tqueue.t) Base.Hashtbl.t

let create () =
  let inbox = Base.Hashtbl.Poly.create () in
  let _ = Base.Hashtbl.add inbox ~key:Message.Request ~data:(Tqueue.create ()) in
  let _ =
    Base.Hashtbl.add inbox ~key:Message.Response ~data:(Tqueue.create ()) in
  let _ =
    Base.Hashtbl.add inbox ~key:Message.Uncategorized ~data:(Tqueue.create ())
  in
  inbox

let find_or_create_category inbox category =
  Base.Hashtbl.find_or_add inbox category ~default:(fun () -> Tqueue.create ())

let next inbox ?(consume = true) category =
  category
  |> find_or_create_category inbox
  |> if consume then Tqueue.take else Tqueue.peek

let await_next inbox ?(consume = true) category =
  category
  |> find_or_create_category inbox
  |> if consume then Tqueue.wait_to_take else Tqueue.wait_to_peek

let push inbox category message =
  category |> find_or_create_category inbox |> Tqueue.add message
