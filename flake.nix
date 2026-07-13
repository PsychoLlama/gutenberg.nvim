{
  description = "Development environment";

  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
    }:

    let
      inherit (nixpkgs) lib;

      eachSystem = lib.flip lib.mapAttrs (
        lib.genAttrs (import systems) (system: nixpkgs.legacyPackages.${system})
      );

      # The directory trees that make up the packaged plugin.
      packagedSources = [
        ./lua
        ./doc
        ./queries
      ];

      # Every `tests/` directory anywhere under `dir`, as a list of paths.
      #
      # `lib.fileset` deliberately has no ancestor- or glob-based
      # exclusion — `fileFilter`'s predicate only sees a file's own name,
      # never the directories above it — so "drop any tests/ directory at
      # any depth" can't be expressed with the fileset combinators alone.
      # We enumerate the test dirs ourselves and subtract them below. This
      # does not weaken the fileset: the walk only reads the source tree
      # that's already being packaged, and its result is fed straight back
      # into `difference`, so the final source is still a plain, precise
      # fileset (which is itself implemented on top of `readDir`).
      testDirsUnder =
        dir:
        lib.concatLists (
          lib.mapAttrsToList (
            name: type:
            if type != "directory" then
              [ ]
            else if name == "tests" then
              [ (dir + "/${name}") ]
            else
              testDirsUnder (dir + "/${name}")
          ) (lib.filesystem.readDir dir)
        );
    in

    {
      packages = eachSystem (
        system: pkgs: {
          default = pkgs.vimUtils.buildVimPlugin {
            pname = "gutenberg.nvim";
            version = self.shortRev or "latest";
            # Specs and their support live in `tests/` directories beside
            # the modules they cover; drop every such directory so the
            # packaged plugin ships only runtime source and docs.
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.difference (lib.fileset.unions packagedSources) (
                lib.fileset.unions (lib.concatMap testDirsUnder packagedSources)
              );
            };
          };
        }
      );

      devShells = eachSystem (
        system: pkgs: rec {
          default = pkgs.mkShell {
            packages = [
              pkgs.just
              pkgs.lua-language-server
              pkgs.luajitPackages.luacheck
              pkgs.luajitPackages.vusted
              pkgs.nixfmt
              pkgs.prettier
              pkgs.stylua
              pkgs.treefmt
            ];
          };

          ci = pkgs.mkShell {
            inputsFrom = [ default ];
            packages = [ pkgs.neovim ];
          };
        }
      );
    };
}
