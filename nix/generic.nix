{ pkgs, stdenv, lib, ocamlPackages, static ? false, doCheck }:

with ocamlPackages; rec {
  pollinate = buildDunePackage {
    pname = "pollinate";
    version = "0.1.0";

    src = lib.filterGitSource {
      src = ./..;
      dirs = [ "src" ];
      files = [ "dune-project" "pollinate.opam" ];
    };

    checkInputs = [ alcotest alcotest-lwt ];

<<<<<<< HEAD
    propagatedBuildInputs = [ lwt lwt_ppx bin_prot ppx_bin_prot ppx_deriving sexplib ppx_hash];
=======
    propagatedBuildInputs = [ lwt lwt_ppx bin_prot ppx_bin_prot ppx_deriving sexplib ppx_hash ];
>>>>>>> 1f440b566cb2365e35926ee00f64de177d9aa649

    inherit doCheck;

    meta = {
      description =
        "A platform agnostic library for P2P communications using UDP and Bin_prot";
    };
  };
}
