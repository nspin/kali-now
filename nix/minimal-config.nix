{ lib, config, pkgs, modulesPath, ... }:

let
  inherit (config.system.build) theseImages;

in {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  config = {

    system.stateVersion = config.system.nixos.release;

    boot.isContainer = true;

    networking.useDHCP = false;
    networking.resolvconf.enable = false;

    # TODO these should work
    # networking.resolvconf.enable = true;
    # networking.useHostResolvConf = true;

    # HACK networking.useHostResolvConf broken, this causes failed ln rather than overwriting
    environment.etc."resolv.conf".text = "";
  
    # revert from minimal.nix avoid rebuilds
    environment.noXlibs = false;

    nix.enable = false;
    networking.firewall.enable = false;

    # services.getty.autologinUser = "root";

    # NOTE container=docker is for https://systemd.io/CONTAINER_INTERFACE/

    system.build.containerInit = pkgs.writeScript "x.sh" ''
      #!${pkgs.runtimeShell}
      ${pkgs.coreutils}/bin/printf "%s" "$DISPLAY" > /run/hack/display
      exec ${pkgs.coreutils}/bin/env -i container=docker ${config.system.build.toplevel}/init  
    '';

  };

}
