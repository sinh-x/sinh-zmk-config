{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-python.url = "github:NixOS/nixpkgs/nixos-23.11";
    zmk-nix = {
      url = "github:lilyinstarlight/zmk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zmk-nix,
      nixpkgs-python,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (nixpkgs.lib.attrNames zmk-nix.packages);
    in
    {
      packages = forAllSystems (system: rec {
        default = firmware;

        firmware = zmk-nix.legacyPackages.${system}.buildSplitKeyboard {
          name = "firmware";
          src = nixpkgs.lib.sourceFilesBySuffices self [
            ".board"
            ".cmake"
            ".conf"
            ".defconfig"
            ".dts"
            ".dtsi"
            ".json"
            ".keymap"
            ".overlay"
            ".shield"
            ".yml"
            "_defconfig"
          ];
          board = "nice_nano_v2";
          shield = "corne_%PART%";
          zephyrDepsHash = "sha256-79/rYCtUDlC0K4ARO9MSEaCcI1RQSsv7MCeayVZSwtQ=";
          meta = {
            description = "ZMK firmware";
            license = nixpkgs.lib.licenses.mit;
            platforms = nixpkgs.lib.platforms.all;
          };
        };

        flash = zmk-nix.packages.${system}.flash.override { inherit firmware; };
        update = zmk-nix.packages.${system}.update;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-python = nixpkgs-python.legacyPackages.${system};
        in
        {
          default = zmk-nix.devShells.${system}.default.overrideAttrs (oldAttrs: {
            buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
              pkgs-python.python310
              pkgs-python.python310Packages.setuptools
              pkgs-python.python310Packages.protobuf
            ];
          });
        }
      );
    };

}
