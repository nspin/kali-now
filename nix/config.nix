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

    system.stateVersion = config.system.nixos.release;

    boot.isContainer = true;
    nix.enable = false;
    networking.firewall.enable = false;

    security.sudo.wheelNeedsPassword = false;
    # users.mutableUsers = false;
    # users.allowNoPasswordLogin = true;

    # services.getty.autologinUser = "root";
    services.getty.autologinUser = "x";

    system.build.containerInit = pkgs.writeScript "x.sh" ''
      #!${pkgs.runtimeShell}
      ${pkgs.coreutils}/bin/mkdir /container-init
      ${pkgs.coreutils}/bin/cp -r /etc /container-init
      ${pkgs.coreutils}/bin/env > /container-init/env.txt
      exec ${pkgs.coreutils}/bin/env -i ${config.system.build.toplevel}/init  
    '';

    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.allowedBridges = [
      "vbr0"
    ];

    programs.virt-manager.enable = true;

    ids.uids.qemu-libvirtd = lib.mkForce 1000;
    users.users.qemu-libvirtd.isSystemUser = true;

    users.users.x = {
      # uid = 1000;
      isNormalUser = true;
      # password = "";
      extraGroups = [ "wheel" ];
    };

    # users.users.x = {
    #   # uid = 1000;
    #   isNormalUser = true;
    #   # password = "";
    #   extraGroups = [ "wheel" ];
    # };

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

    environment.systemPackages = [
      system.build.refreshXauthority
    ];

    environment.sessionVariables = {
        XAUTHORITY = "$HOME/.Xauthority";
    };

    system.build.refreshXauthority = pkgs.writeShellApplication {
      name = "refresh-xauthority";
      runtimeInputs = with pkgs; [
        xauth
        gnused
      ];
      text = ''
        xauth -i -f /host.Xauthority nlist |  sed -e 's/^..../ffff/' |  bin/xauth -f $XAUTHORITY nmerge -
      '';
    };

    system.build.s = pkgs.writeShellApplication {
      name = "x";
      runtimeInputs = with pkgs; [
        iproute2
        iptables
      ];
      text = ''
        br_addr="192.168.122.1"
        br_dev="vbr0"
        ip link add $br_dev type bridge stp_state 1 forward_delay 0
        ip link set $br_dev up
        ip addr add $br_addr/16 dev $br_dev
        iptables -t nat -F
        iptables -t nat -A POSTROUTING -s $br_addr/16 ! -o $br_dev -j MASQUERADE
      '';
    };

    networking.localCommands = ''
      ${config.system.build.s}/bin/*
    '';

  };

}
