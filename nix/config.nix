{ lib, config, pkgs, modulesPath, ... }:

let

in {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/headless.nix"
  ];

  config = {
    boot.isContainer = true;
    users.mutableUsers = false;
    nix.enable = false;
    networking.firewall.enable = false;

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

    system.build.containerInit = pkgs.writeScript "x.sh" ''
      #!${pkgs.runtimeShell}
      ${pkgs.coreutils}/bin/mkdir /container-init
      ${pkgs.coreutils}/bin/cp -r /etc /container-init
      ${pkgs.coreutils}/bin/env > /container-init/env.txt
      exec ${pkgs.coreutils}/bin/env -i ${config.system.build.toplevel}/init  
    '';
  };
}
