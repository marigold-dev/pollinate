(** Defines utilities for working with payloads
that are or need to be serialized via Bin_prot *)
module Encoding : sig
  val size_header_length : int
  (** The int value of the buffer size *)

  val read_size_header : bytes -> int
  (** Reads the value of the size header prepended
  to a serialized Bin_prot payload *)

  val pack : 'a Bin_prot.Type_class.writer -> 'a -> bytes
  (** Serializes a payload using a Bin_prot
  writer corresponding to its type *)

  val unpack : 'a Bin_prot.Read.reader -> bytes -> 'a
  (** Deserializes a payload using a Bin_prot reader
  corresponding to its type. The payload being deserialized
  MUST have an 8 byte size header, or this function will
  behave incorrectly *)
end

(** Defines utilities for working with UDP sockets *)
module Net : sig
  val create_socket : int -> Lwt_unix.file_descr Lwt.t
  (** Creates and binds a socket to localhost:<port> where
  port is the lone argument to this function *)
end
