(lang dune 2.9)

(name pollinate)

(generate_opam_files true)

(source
 (github marigold-dev/pollinate))

(authors "Ambika Eshwar, Gauthier Sebille")

(maintainers "Ambika Eshwar, Gauthier Sebille")

(license LICENSE)

; (documentation https://url/to/documentation)

(package
 (name pollinate)
 (synopsis
  "A platform agnostic library for P2P communications using UDP and Bin_prot")
 (description
  "A platform agnostic library for P2P communications using UDP and Bin_prot")
 (depends
  ocaml
  dune
  lwt
  sexplib
  lwt_ppx
  bin_prot
  ppx_bin_prot
  ppx_compare
  ppx_hash
  ppx_sexp_conv
  (alcotest-lwt :with-test)
  (ppx_deriving :with-test))
 (tags
  (p2p networking udp "gossip protocol")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
