{ lib
, pkgs
}:

let

in rec {
  system = import (pkgs.path + "/nixos") {
    configuration.imports = [
      ./config.nix
      # ./minimal-config.nix
    ];
  };

  inherit (system.config.system.build.kaliNow) containerInit containerXauthority;
}
