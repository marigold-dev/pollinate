type 'a t = {
  queue : 'a Queue.t;
  lock : Lwt_mutex.t;
  mailbox : 'a Lwt_mvar.t;
}

let create () =
  let queue = Queue.create () in
  let lock = Lwt_mutex.create () in
  let mailbox = Lwt_mvar.create_empty () in
  { queue; lock; mailbox }

let add x { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      if Lwt_mvar.is_empty mailbox then
        Lwt_mvar.put mailbox x
      else
        Lwt.return (Queue.add x queue))

let push = add

let fill_mailbox queue mailbox =
  if Lwt_mvar.is_empty mailbox then
    match Queue.take_opt queue with
    | None -> Lwt.return ()
    | Some value -> Lwt_mvar.put mailbox value
  else
    Lwt.return ()

let take_exn { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      let value_opt = Lwt_mvar.take_available mailbox in
      let value =
        match value_opt with
        | None -> raise Queue.Empty
        | Some value -> Lwt.return value in
      let%lwt () = fill_mailbox queue mailbox in
      value)

let take_opt { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      let value = Lwt.return (Lwt_mvar.take_available mailbox) in
      let%lwt () = fill_mailbox queue mailbox in
      value)

let take_block { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      let value = Lwt_mvar.take mailbox in
      let%lwt () = fill_mailbox queue mailbox in
      value)

let pop = take_exn

let peek { lock; mailbox; _ } =
  Lwt_mutex.with_lock lock (fun () ->
      let value_opt = Lwt_mvar.take_available mailbox in
      let value =
        match value_opt with
        | None -> raise Queue.Empty
        | Some value ->
          let%lwt () = Lwt_mvar.put mailbox value in
          Lwt.return value in
      value)

let peek_opt { lock; mailbox; _ } =
  Lwt_mutex.with_lock lock (fun () ->
      let value_opt = Lwt_mvar.take_available mailbox in
      let value =
        match value_opt with
        | None -> Lwt.return None
        | Some value ->
          let%lwt () = Lwt_mvar.put mailbox value in
          Lwt.return (Some value) in
      value)

let top = peek

let clear { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      ignore (Lwt_mvar.take_available mailbox);
      Lwt.return (Queue.clear queue))

let copy { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      let queue' = Queue.copy queue in
      let lock' = Lwt_mutex.create () in
      let mailbox' =
        match Lwt_mvar.take_available mailbox with
        | None -> Lwt_mvar.create_empty ()
        | Some value -> Lwt_mvar.create value in
      Lwt.return { queue = queue'; lock = lock'; mailbox = mailbox' })

let is_empty { lock; mailbox; _ } =
  Lwt_mutex.with_lock lock (fun () -> Lwt.return (Lwt_mvar.is_empty mailbox))

let length { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      let l = Queue.length queue + if Lwt_mvar.is_empty mailbox then 0 else 1 in
      Lwt.return l)

let iter f { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      let mb_value = Lwt_mvar.take_available mailbox in
      let first_result =
        match mb_value with
        | None -> Lwt.return None
        | Some value ->
          let%lwt () = f value in
          Lwt.return (Some ()) in
      match%lwt first_result with
      | None -> Lwt.return ()
      | Some () ->
        let q = Queue.to_seq queue in
        let _v = Seq.map f q in
        Lwt.return ())

let fold f accu { queue; lock; mailbox } =
  Lwt_mutex.with_lock lock (fun () ->
      match Lwt_mvar.take_available mailbox with
      | None -> Lwt.return accu
      | Some value ->
        queue
        |> Queue.to_seq
        |> Seq.cons value
        |> Seq.fold_left f accu
        |> Lwt.return)

(* let transfer q1 q2 =
     let%lwt () = iter (fun x -> add x q2) q1 in
     clear q1

   let to_seq { queue; lock } =
     Lwt_mutex.with_lock lock (fun () -> Lwt.return (Queue.to_seq queue))

   let add_seq { queue; lock } seq =
     Lwt_mutex.with_lock lock (fun () -> Lwt.return (Queue.add_seq queue seq))

   let of_seq seq =
     let queue = Queue.of_seq seq in
     let lock = Lwt_mutex.create () in
     { queue; lock } *)
