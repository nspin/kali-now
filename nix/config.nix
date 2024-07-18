{ lib, config, pkgs, modulesPath, ... }:

let

in {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    # "${modulesPath}/profiles/perlless.nix"
    # "${modulesPath}/profiles/headless.nix"
  ];

  config = {
    boot.isContainer = true;
    nix.enable = false;
    # system.switch.enable = false;
    # users.mutableUsers = false;
    system.stateVersion = "24.11";

    services.getty.autologinUser = "root";
  };
}
