{ pkgs, stdenv, lib, nix-filter, ocamlPackages, doCheck }:

with ocamlPackages;
buildDunePackage {
  pname = "pollinate";
  version = "0.1.0";

  # Using nix-filter means we only rebuild when we have to
  src = with nix-filter.lib;
    filter {
      root = ../.;
      include = [
        "dune-project"
        "pollinate.opam"
        "README.md"
        (inDirectory "lib")
        (inDirectory "test")
      ];
    };

  checkInputs = [ alcotest alcotest-lwt ];

  propagatedBuildInputs = [
    lwt
    lwt_ppx
    bin_prot
    ppx_bin_prot
    ppx_deriving
    sexplib
    ppx_hash
    qcheck-core
    qcheck-alcotest
  ];

  inherit doCheck;

  meta = {
    description =
      "A platform agnostic library for P2P communications using UDP and Bin_prot";
  };
}
