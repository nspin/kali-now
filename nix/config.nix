{ lib, config, pkgs, modulesPath, ... }:

let
  inherit (config.system.build.kaliNow)
    runtimeDiskPath vmQcow2 networkXml vmXml
  ;

  ifaceToHost = "eth0";
  bridgeName = "vbr0";

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
    environment.etc."resolv.conf".text = lib.mkForce "";
  
    # revert from minimal.nix avoid rebuilds
    environment.noXlibs = false;

    nix.enable = false;

    services.getty.autologinUser = "root";

    # NOTE container=docker is for https://systemd.io/CONTAINER_INTERFACE/

    system.build.containerInit = pkgs.writeScript "x.sh" ''
      #!${pkgs.runtimeShell}
      exec ${pkgs.coreutils}/bin/env -i container=docker ${config.system.build.toplevel}/init  
    '';

    networking.usePredictableInterfaceNames = false;

    networking.firewall.enable = false;

    # networking.firewall.enable = true;
    # networking.firewall.logRefusedPackets = true;
    # networking.firewall.allowedUDPPorts = [ 53 67 ];

    networking.useNetworkd = true;
    networking.useHostResolvConf = false;

    systemd.network = {
      netdevs = {
        "20-${bridgeName}" = {
          netdevConfig = {
            Kind = "bridge";
            Name = bridgeName;
          };
        };
      };
      networks = {
        "30-${ifaceToHost}" = {
          matchConfig.Name = ifaceToHost;
          networkConfig.Bridge = bridgeName;
          # linkConfig.RequiredForOnline = "enslaved";
        };
        "40-${bridgeName}" = {
          matchConfig.Name = bridgeName;
          bridgeConfig = {};
          address = [ 
            "192.168.122.1/24"
          ]; 
          # Disable address autoconfig when no IP configuration is required
          # networkConfig.LinkLocalAddressing = "no";
          # linkConfig = {
          #   # or "routable" with IP addresses configured
          #   RequiredForOnline = "carrier";
          # };
        };
      };
    };

    # networking.bridges = {
    #   "${bridgeName}" = {
    #     interfaces = [
    #       "eth0"
    #     ];
    #   };
    # };

    # networking.dhcpcd.enable = false;

    # networking.interfaces = {
    #   eth0 = {
    #     useDHCP = false;
    #   };
    #   "${bridgeName}" = {
    #     # networking.interfaces.abc = {
    #       useDHCP = false;
    #       # useDHCP = true;
    #       # useDHCP = null;
    #       ipv4.addresses = [
    #         {
    #           address = "192.168.122.1";
    #           prefixLength = 24;
    #         }
    #       ];
    #       # virtual = true;
    #     };
    # };

    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.allowedBridges = [
      bridgeName
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

    # services.dnsmasq = {
    #   enable = true;
    #   resolveLocalQueries = false;
    #   settings = {
    #     interface = bridgeName;
    #     dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0,96h";
    #     # dhcp-option = [
    #     #   "option:router,192.168.122.1"
    #     #   "option:dns-server,192.168.122.1"
    #     # ];
    #     # log-dhcp = true;
    #     # log-queries = true;
    #   };
    # };

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

    # system.build.setupVMNetwork = pkgs.writeShellApplication {
    #   name = "setup-vm-network";
    #   runtimeInputs = with pkgs; [
    #     iproute2
    #     iptables
    #   ];
    #   text = ''
    #     br_addr="192.168.122.1"
    #     br_dev="vbr0"
    #     ip link add $br_dev type bridge stp_state 1 forward_delay 0
    #     ip link set $br_dev up
    #     ip addr add $br_addr/16 dev $br_dev
    #     iptables -t nat -F
    #     iptables -t nat -A POSTROUTING -s $br_addr/16 ! -o $br_dev -j MASQUERADE
    #   '';
    # };

    # TODO doesn't work
    # networking.localCommands = ''
    #   ${config.system.build.setupVMNetwork}/bin/*
    # '';

    environment.systemPackages = with pkgs; [
      xorg.xauth
      qemu
      libvirt

      # utils
      config.system.build.xsetup
      config.system.build.xrun

      # debugging
      strace
      inetutils
      ethtool
    ];

    system.build.xsetup = pkgs.writeShellApplication {
      name = "xsetup";
      runtimeInputs = with pkgs; [
        qemu
        libvirt
        # config.system.build.setupVMNetwork
      ];
      checkPhase = false;
        # sudo ${config.system.build.setupVMNetwork.name}
      text = ''
        ensure_user_dir() {
          if [ ! -d $1 ]; then
            sudo mkdir -p $1
            sudo chown x:x $1
          fi
        }

        shared_root=/shared
        shared_dirs="$shared_root/container $shared_root/vm"
        for d in $shared_dirs; do
          ensure_user_dir $d
        done

        ensure_user_dir $(dirname ${runtimeDiskPath})

        if [ ! -f ${runtimeDiskPath} ]; then
          qemu-img create -f qcow2 -o backing_fmt=qcow2 -o backing_file=${vmQcow2} ${runtimeDiskPath}
        fi

        virsh_c() {
          virsh -c qemu:///session "$@"
        }

        virsh_c net-define ${networkXml}
        virsh_c net-autostart kali-network
        virsh_c net-start kali-network
        virsh_c define ${vmXml}
      '';
    };

    system.build.xrun = pkgs.writeShellApplication {
      name = "xrun";
      checkPhase = false;
      text = ''
        virt-manager -c qemu:///session
      '';
    };

  };

}
