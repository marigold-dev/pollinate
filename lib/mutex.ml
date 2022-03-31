type 'a t = {
  value : 'a;
  mutex : Lwt_mutex.t;
  mutable lock_counter : int;
}

let create value =
  let mutex = Lwt_mutex.create () in
  let lock_counter = 0 in
  { value; mutex; lock_counter }

let lock t =
  let%lwt () = Lwt_mutex.lock t.mutex in
  t.lock_counter <- t.lock_counter + 1;
  Lwt.return t.value

let unlock t =
  Lwt_mutex.unlock t.mutex;
  t.lock_counter <- t.lock_counter - 1

let is_locked t = Lwt_mutex.is_locked t.mutex

let with_lock t f =
  let%lwt value = lock t in
  t.lock_counter <- t.lock_counter + 1;
  let%lwt result = f value in
  unlock t;
  Lwt.return result

let unsafe t f = f t.value
