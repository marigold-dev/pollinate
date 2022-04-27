# Pollinate

A platform agnostic OCaml library for P2P communications using UDP and Bin_prot.
Technical documentation is available [here](https://marigold-dev.github.io/pollinate/).

## Building and Running Tests

### With `esy`

Install [`esy`](https://esy.sh/).

```shell script
# Build
$ esy

# Test
$ esy x dune test
```

### With `nix`

Make sure you don't have a globally installed `dune` because it would
lead to conflicts since we provide it via `nix`.

- Install [`nix`](https://nixos.org/download.html).
- Install [`direnv`](https://direnv.net/docs/installation.html)

Then run the following commands:

```shell script
# cd to the folder of Pollinate
$ cd pollinate

# Allow direnv to load the nix environment
$ direnv allow

# Run test
$ dune test
```

## Documentation

A built-in documentation with [`odoc`](https://github.com/ocaml/odoc) is available [here](https://marigold-dev.github.io/pollinate/).

In case you want to rebuild it locally (for example, you made changes and want to see them before pushing):

```shell script
$ dune build @doc
```
