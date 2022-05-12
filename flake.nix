{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";

    ocaml-overlay.url = "github:anmonteiro/nix-overlays";
    ocaml-overlay.inputs.nixpkgs.follows = "nixpkgs";
    ocaml-overlay.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, nix-filter, ocaml-overlay }:
    let
      supported_ocaml_versions = [ "ocamlPackages_4_13" "ocamlPackages_5_00" ];
      out = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ ocaml-overlay.overlays."${system}".default ];
          };
          pollinate = (pkgs.callPackage ./nix {
            inherit nix-filter;
            doCheck = true;
            ocamlPackages = pkgs.ocaml-ng.ocamlPackages_5_00;
          });
        in {
          devShells = {
            default = (pkgs.mkShell {
              inputsFrom = [ pollinate ];
              buildInputs = with pkgs;
                with ocamlPackages; [
                  ocaml-lsp
                  ocamlformat
                  odoc
                  ocaml
                  dune_3
                  nixfmt
                ];
            });
          };

          formatter = pkgs.nixfmt;

          packages = builtins.foldl' (prev: ocamlVersion:
            prev // {
              "pollinate_${ocamlVersion}" = pollinate.override {
                ocamlPackages = pkgs.ocaml-ng."${ocamlVersion}";
              };
            }) {
              # ocaml 5.00 version is available as default, pollinate and pollinate_ocamlPackage_5_00
              inherit pollinate;
              default = pollinate;
            } supported_ocaml_versions;
        };
    in with flake-utils.lib;
    eachSystem [
      system.x86_64-linux
      system.aarch64-linux
      system.x86_64-darwin
      system.aarch64-darwin
    ] out // {
      overlays.default =
        import ./nix/overlay.nix supported_ocaml_versions nix-filter;
      hydraJobs = {
        x86_64-linux.default = self.packages.x86_64-linux;
        aarch64-darwin.default = self.packages.aarch64-darwin;
      };
    };

}
