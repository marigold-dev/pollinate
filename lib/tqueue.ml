type 'a t = {
  queue : 'a Queue.t;
  lock : Lwt_mutex.t;
  has_elt : unit Lwt_condition.t;
}

let create () =
  let queue = Queue.create () in
  let lock = Lwt_mutex.create () in
  let has_elt = Lwt_condition.create () in
  { queue; lock; has_elt }

let add x { queue; lock; has_elt } =
  Lwt_mutex.with_lock lock (fun () ->
      Queue.add x queue;
      let%lwt () =
        if Queue.length queue = 1 then (
          Lwt_condition.signal has_elt ();
          Lwt.return ())
        else
          Lwt.return () in
      Lwt.return ())

let push = add

let take { queue; lock; _ } =
  Lwt_mutex.with_lock lock (fun () -> Lwt.return (Queue.take_opt queue))

let wait_to_take { queue; lock; has_elt } =
  Lwt_mutex.with_lock lock (fun () ->
      let%lwt () =
        if Queue.is_empty queue then
          Lwt_condition.wait ~mutex:lock has_elt
        else
          Lwt.return () in
      Lwt.return (Queue.take queue))

let pop = take

let peek { queue; lock; _ } =
  Lwt_mutex.with_lock lock (fun () -> Lwt.return (Queue.peek_opt queue))

let wait_to_peek { queue; lock; has_elt } =
  Lwt_mutex.with_lock lock (fun () ->
      let%lwt () =
        if Queue.is_empty queue then
          Lwt_condition.wait ~mutex:lock has_elt
        else
          Lwt.return () in
      Lwt.return (Queue.peek queue))


let top = peek

let clear { queue; lock; _ } =
  Lwt_mutex.with_lock lock (fun () -> Lwt.return (Queue.clear queue))

let copy { queue; lock; _ } =
  Lwt_mutex.with_lock lock (fun () ->
      let queue' = queue in
      let lock' = Lwt_mutex.create () in
      let has_elt' = Lwt_condition.create () in
      Lwt.return { queue = queue'; lock = lock'; has_elt = has_elt' })

let is_empty { queue; lock; _ } =
  Lwt_mutex.with_lock lock (fun () -> Lwt.return (Queue.is_empty queue))

let length { queue; lock; _ } =
  Lwt_mutex.with_lock lock (fun () -> Lwt.return (Queue.length queue))
