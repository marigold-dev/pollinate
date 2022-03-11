(** Defines utilities for working with payloads
that are or need to be serialized via Bin_prot *)
module Encoding : sig
  (** The int value of the buffer size *)
  val size_header_length : int

  (** Reads the value of the size header prepended
  to a serialized Bin_prot payload *)
  val read_size_header : bytes -> int

  (** Serializes a payload using a Bin_prot
  writer corresponding to its type *)
  val pack : 'a Bin_prot.Type_class.writer -> 'a -> bytes

  (** Deserializes a payload using a Bin_prot reader
  corresponding to its type. The payload being deserialized
  MUST have an 8 byte size header, or this function will
  behave incorrectly *)
  val unpack : 'a Bin_prot.Read.reader -> bytes -> 'a
end

(** Defines utilities for working with UDP sockets *)
module Net : sig
  (** Creates and binds a socket to localhost:<port> where
  port is the lone argument to this function *)
  val create_socket : int -> Lwt_unix.file_descr Lwt.t
end
