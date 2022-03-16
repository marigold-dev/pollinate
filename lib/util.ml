open Lwt

module Encoding = struct
  open Bin_prot
  open Bin_prot.Utils

  (* Bin_prot fixed size header. *)
  let size_header_length = 8

  let read_all reader buf = reader buf ~pos_ref:(ref 0)

  let read_size_header byte_buff =
    let buf = Common.create_buf size_header_length in
    Common.blit_bytes_buf byte_buff buf ~len:size_header_length;
    read_all bin_read_size_header buf

  let prepare_buff byte_buff =
    let len = Bytes.length byte_buff - size_header_length in
    let buf = Common.create_buf len in
    Common.blit_bytes_buf ~src_pos:size_header_length byte_buff buf ~len;
    buf

  let pack writer payload =
    let buf = bin_dump ~header:true writer payload in
    let len = Common.buf_len buf in
    let byte_buff = Bytes.create len in
    Common.blit_buf_bytes buf byte_buff ~len;
    byte_buff

  let unpack reader payload =
    let buf = prepare_buff payload in
    read_all reader buf

  let str_dump payload =
    payload
    |> Bytes.to_seq
    |> Seq.map int_of_char
    |> Seq.map string_of_int
    |> List.of_seq
    |> String.concat " ; "
end

module Net = struct
  let create_socket port =
    let open Lwt_unix in
    let ssock = socket PF_INET SOCK_DGRAM 0 in
    let addr = ADDR_INET (Unix.inet_addr_loopback, port) in
    let%lwt () = bind ssock addr in
    return ssock
end
