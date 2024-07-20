{ lib, config, pkgs, modulesPath, ... }:

let

in {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/headless.nix"
  ];

  config = {

    # avoid rebuilds
    environment.noXlibs = false;

    boot.isContainer = true;
    nix.enable = false;
    networking.firewall.enable = false;
    users.mutableUsers = false;

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

    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.allowedBridges = [
    ];

    programs.virt-manager.enable = true;

    services.dnsmasq = lib.optionalAttrs false {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        strict-order = true;
        except-interface = "lo";
        bind-dynamic = true;
        interface = "vbr0";
        dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0";
        dhcp-no-override = true;
        dhcp-authoritative = true;
        dhcp-lease-max = "253";

        # dhcp-range = "192.168.12.100,192.168.12.200,96h";
        # dhcp-option = [ 
        #   "option:router,192.168.12.1"
        #   "option:dns-server,192.168.12.1"
        # ];
        # log-dhcp = true;
        # log-queries = true;
      };
    };

  };

}
