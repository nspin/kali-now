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
    users.mutableUsers = false;
    nix.enable = false;
    networking.firewall.enable = false;

    # system.switch.enable = false;

    system.stateVersion = "24.11";

    # services.getty.autologinUser = "root";
    services.getty.autologinUser = "x";

    security.sudo.wheelNeedsPassword = false;

    users.extraUsers.x = {
      uid = 1000;
      isNormalUser = true;
      password = "";
      extraGroups = [ "wheel" ];
    };
  };
}
