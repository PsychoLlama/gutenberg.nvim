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
    in

    {
      packages = eachSystem (
        system: pkgs:
        let
          sources = lib.fileset.unions [
            ./lua
            ./doc
          ];
          specs = lib.fileset.fileFilter (file: lib.hasSuffix "_spec.lua" file.name) ./.;
        in
        {
          default = pkgs.vimUtils.buildVimPlugin {
            pname = "gutenberg.nvim";
            version = "0-unstable";
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.difference sources specs;
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
