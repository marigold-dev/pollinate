{ pkgs }:

pkgs.writeShellApplication {
  name = "format.sh";
  runtimeInputs = with pkgs; [ treefmt nixfmt ocamlformat_0_20_1 ocaml dune_3 ];
  text = ''treefmt "$@"'';
}
