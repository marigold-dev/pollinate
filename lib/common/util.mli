(** Defines utilities for working with payloads
that are or need to be serialized via {{:https://github.com/janestreet/bin_prot}[Bin_prot]}. *)

(**/**)

val ( let* ) : 'a option -> ('a -> 'b option) -> 'b option

(**/**)

module Encoding : sig
  (** Defines utilities for encoding or decoding messages. *)

  val size_header_length : int
  (** The {i int} value of the necessary buffer size for storing the size
      header at the beginning of each Bin_prot payload. *)

  val read_size_header : bytes -> int
  (** Reads the value of the size header prepended
  to a serialized [Bin_prot] payload. *)

  val pack : 'a Bin_prot.Type_class.writer -> 'a -> bytes
  (** Serializes a payload using a [Bin_prot writer] 
  corresponding to its type. *)

  val unpack : 'a Bin_prot.Read.reader -> bytes -> 'a
  (** Deserializes a payload using a [Bin_prot reader]
  corresponding to its type. The payload being deserialized
  {b MUST} have an 8 bytes size header, or this function will
  behave incorrectly. *)

  val str_dump : bytes -> string
  (** Produces a {i string} consisting of semi-colon (;) separated
integer-representations of each byte in the input bytes. *)
end

module Net : sig
  (** Defines utilities for working with UDP sockets *)

  val create_socket : int -> Lwt_unix.file_descr Lwt.t
  (** Creates and binds a socket to [localhost:<port>] where
  [port] is the lone argument to this function *)
end
