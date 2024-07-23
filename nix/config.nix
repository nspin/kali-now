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

    # services.getty.autologinUser = "root";

    # NOTE container=docker is for https://systemd.io/CONTAINER_INTERFACE/

    system.build.containerInit = pkgs.writeScript "x.sh" ''
      #!${pkgs.runtimeShell}
      exec ${pkgs.coreutils}/bin/env -i container=docker ${config.system.build.toplevel}/init  
    '';

    networking.firewall.enable = false;

    # networking.firewall.enable = true;
    # networking.firewall.logRefusedPackets = true;
    # networking.firewall.allowedUDPPorts = [ 53 67 ];

    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.allowedBridges = [
      "vbr0"
    ];

    virtualisation.spiceUSBRedirection.enable = true;

    security.polkit.debug = true;

    programs.virt-manager.enable = true;

    # ids.uids.qemu-libvirtd = lib.mkForce 1000;
    # users.users.qemu-libvirtd.isSystemUser = true;

    users.users.x = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    security.sudo.wheelNeedsPassword = false;

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
          if (action.id == "org.spice-space.lowlevelusbaccess" && subject.isInGroup("wheel")){
              return polkit.Result.YES;
          }
      });
    '';

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        interface = "vbr0";
        dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0,96h";
        dhcp-option = [
          "option:router,192.168.122.1"
          "option:dns-server,192.168.122.1"
        ];
        # log-dhcp = true;
        # log-queries = true;
      };
    };

    # services.dnsmasq = {
    #   enable = true;
    #   resolveLocalQueries = false;
    #   settings = {
    #     strict-order = true;
    #     except-interface = "lo";
    #     bind-dynamic = true;
    #     interface = "vbr0";
    #     dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0";
    #     dhcp-no-override = true;
    #     dhcp-authoritative = true;
    #     dhcp-lease-max = "253";
    #   };
    # };

    environment.systemPackages = [
      pkgs.xorg.xauth
      pkgs.qemu
      pkgs.libvirt
      config.system.build.run
      config.system.build.xsetup
    ];

    system.build.xsetup = with theseImages; pkgs.writeShellApplication {
      name = "xsetup";
      runtimeInputs = with pkgs; [
        qemu
        libvirt
      ];
      checkPhase = false;
      text = ''
        sudo ${config.system.build.s}/bin/*

        ensure_user_dir() {
          if [ ! -d $1 ]; then
            sudo mkdir -p $1
            sudo chown x:x $1
          fi
        }

        shared_base=/shared
        shared_dirs="$shared_base/container $shared_base/vm"
        ensure_user_dir $shared_base
        for d in $shared_dirs; do
          ensure_user_dir $d
        done

        ensure_user_dir ${runtimeImageDirectory}

        ensure_image() {
          if [ ! -f ${runtimeImageDirectory}/$2 ]; then
            qemu-img create -f qcow2 -o backing_fmt=qcow2 -o backing_file=$1 ${runtimeImageDirectory}/$2
          fi
        }

        ensure_image ${vmQcow2} vm.qcow2

        virsh_c() {
          virsh -c qemu:///session "$@"
        }

        virsh_c net-define ${networkXml}
        virsh_c net-autostart kali-network
        virsh_c net-start kali-network
        virsh_c define ${vmXml}
      '';
    };

    system.build.run = pkgs.writeShellApplication {
      name = "run";
      checkPhase = false;
      text = ''
        virt-manager -c qemu:///session
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

    # networking.localCommands = ''
    #   ${config.system.build.s}/bin/*
    # '';

  };

}
