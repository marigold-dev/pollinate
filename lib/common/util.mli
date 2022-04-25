(** Defines utilities for working with payloads
that are or need to be serialized via Bin_prot *)

(**/**)

val ( let* ) : 'a option -> ('a -> 'b option) -> 'b option

(**/**)

module Encoding : sig
  (** Defines utilities to properly encode or decode a message *)

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

  (** Produces a string consisting of semi-colon (;) separated
integer-representations of each byte in the input bytes *)
  val str_dump : bytes -> string
end

module Net : sig
  (** Defines utilities for working with UDP sockets *)

  (** Creates and binds a socket to localhost:<port> where
  port is the lone argument to this function *)
  val create_socket : int -> Lwt_unix.file_descr Lwt.t
end
