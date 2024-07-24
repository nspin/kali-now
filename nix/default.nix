let
  nixpkgsPath =
    let
      rev = "9355fa86e6f27422963132c2c9aeedb0fb963d93";
    in
      builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
        # url = "https://github.com/nspin/nixpkgs/archive/refs/tags/keep/${builtins.substring 0 32 rev}.tar.gz";
        sha256 = "sha256:09d402saka836ni93vbc6i9c8js8h6jmbk29zd8cs900cfadir7v";
      };

  pkgs = import nixpkgsPath {};

in rec {
  inherit pkgs;

  system = import (pkgs.path + "/nixos") {
    configuration.imports = [
      ./config.nix
      # ./minimal-config.nix
    ];
  };

  inherit (system.config.system.build) kaliNow;
  inherit (kaliNow) containerInit containerXauthority;
}
