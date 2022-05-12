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

    propagatedBuildInputs = [ lwt lwt_ppx bin_prot ppx_bin_prot ppx_deriving sexplib ppx_hash qcheck qcheck-core qcheck-alcotest];

    inherit doCheck;

    meta = {
      description =
        "A platform agnostic library for P2P communications using UDP and Bin_prot";
    };
  };
}
