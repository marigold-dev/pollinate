open Lwt

module Encoding = struct
  open Bin_prot
  open Bin_prot.Utils

  (* Bin_prot fixed size header. *)
  let bin_prot_buffer_size = 8

  let bin_prot_buffer = Bytes.create bin_prot_buffer_size

  (* Position to start reading a datagram *)
  let read_from_first_byte = 0
  let read_size_header byte_buff =
    let buf = Common.create_buf bin_prot_buffer_size in
    Common.blit_bytes_buf byte_buff buf ~len:bin_prot_buffer_size;
    bin_read_size_header buf ~pos_ref:(ref read_from_first_byte)

  let prepare_buff byte_buff =
    let len = Bytes.length byte_buff - bin_prot_buffer_size in
    let buf = Common.create_buf len in
    Common.blit_bytes_buf ~src_pos:bin_prot_buffer_size byte_buff buf ~len;
    buf

  let pack writer payload =
    let buf = bin_dump ~header:true writer payload in
    let len = Common.buf_len buf in
    let byte_buff = Bytes.create len in
    Common.blit_buf_bytes buf byte_buff ~len;
    byte_buff

  let unpack reader payload =
    let buf = prepare_buff payload in
    reader buf ~pos_ref:(ref read_from_first_byte)
end

module Net = struct
  let create_socket port =
    let open Lwt_unix in
    let ssock = socket PF_INET SOCK_DGRAM 0 in
    let addr = ADDR_INET (Unix.inet_addr_loopback, port) in
    let%lwt () = bind ssock addr in
    return ssock
end
