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

      # Every `tests/` directory anywhere under `dir`. `fileFilter` only
      # sees a file's own name, not its ancestors, so we walk the tree to
      # catch test dirs at any depth rather than hard-coding their paths.
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
          ) (builtins.readDir dir)
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
              fileset = lib.fileset.difference (lib.fileset.unions [
                ./lua
                ./doc
              ]) (lib.fileset.unions (testDirsUnder ./lua ++ testDirsUnder ./doc));
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
