{ lib, config, pkgs, modulesPath, ... }:

let
  inherit (config.system.build) theseImages;

in {
  imports = [
    # "${modulesPath}/profiles/minimal.nix"
    # "${modulesPath}/profiles/headless.nix"
  ];

  config = {
  
    # avoid rebuilds
    # environment.noXlibs = false;

    system.stateVersion = config.system.nixos.release;

    boot.isContainer = true;
    nix.enable = false;

    services.getty.autologinUser = "root";

    # networking.firewall.enable = false;
    # networking.firewall.logRefusedPackets = true;
    # networking.firewall.allowedUDPPorts = [ 53 67 ];

    # security.sudo.wheelNeedsPassword = false;
    # # users.mutableUsers = false;
    # # users.allowNoPasswordLogin = true;

    # # services.getty.autologinUser = "root";
    # services.getty.autologinUser = "x";

    system.build.containerInit = pkgs.writeScript "x.sh" ''
      #!${pkgs.runtimeShell}
      ${pkgs.coreutils}/bin/mkdir /container-init
      ${pkgs.coreutils}/bin/cp -r /etc /container-init
      ${pkgs.coreutils}/bin/env > /container-init/env.txt
      exec ${pkgs.coreutils}/bin/env -i ${config.system.build.toplevel}/init  
    '';

    # virtualisation.libvirtd.enable = true;
    # virtualisation.libvirtd.allowedBridges = [
    #   "vbr0"
    # ];

    # programs.virt-manager.enable = true;

    # # ids.uids.qemu-libvirtd = lib.mkForce 1000;
    # # users.users.qemu-libvirtd.isSystemUser = true;

    # users.users.x = {
    #   uid = 1000;
    #   isNormalUser = true;
    #   # password = "";
    #   extraGroups = [ "wheel" ];
    # };

    # # users.users.x = {
    # #   # uid = 1000;
    # #   isNormalUser = true;
    # #   # password = "";
    # #   extraGroups = [ "wheel" ];
    # # };

    # # services.dnsmasq = {
    # #   enable = true;
    # #   resolveLocalQueries = false;
    # #   settings = {
    # #     strict-order = true;
    # #     except-interface = "lo";
    # #     bind-dynamic = true;
    # #     interface = "vbr0";
    # #     dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0";
    # #     dhcp-no-override = true;
    # #     dhcp-authoritative = true;
    # #     dhcp-lease-max = "253";

    # #     # dhcp-range = "192.168.12.100,192.168.12.200,96h";
    # #     # dhcp-option = [
    # #     #   "option:router,192.168.12.1"
    # #     #   "option:dns-server,192.168.12.1"
    # #     # ];
    # #     # log-dhcp = true;
    # #     # log-queries = true;
    # #   };
    # # };

    # services.dnsmasq = {
    #   enable = true;
    #   resolveLocalQueries = false;
    #   settings = {
    #     interface = "vbr0";
    #     dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0,96h";
    #     dhcp-option = [
    #       "option:router,192.168.122.1"
    #       "option:dns-server,192.168.122.1"
    #     ];
    #     log-dhcp = true;
    #     log-queries = true;
    #   };
    #     # enable-tftp
    #     # tftp-root=/tftpboot
    #     # pxe-service=0,"Raspberry Pi Boot"
    # };

    # environment.systemPackages = [
    #   pkgs.qemu
    #   pkgs.libvirt
    #   config.system.build.refreshXauthority
    #   config.system.build.run
    #   config.system.build.xsetup
    # ];

    # environment.sessionVariables = {
    #     XAUTHORITY = "$HOME/.Xauthority";
    # };

    # system.build.xsetup = with theseImages; pkgs.writeShellApplication {
    #   name = "xsetup";
    #   runtimeInputs = with pkgs; [
    #     qemu
    #     libvirt
    #   ];
    #   checkPhase = false;
    #   text = ''
    #     ensure_user_dir() {
    #       if [ ! -d $1 ]; then
    #         sudo mkdir -p $1
    #         sudo chown x:x $1
    #       fi
    #     }

    #     shared_base=/shared
    #     shared_dirs="$shared_base/container $shared_base/vm"
    #     ensure_user_dir $shared_base
    #     for d in $shared_dirs; do
    #       ensure_user_dir $d
    #     done

    #     ensure_user_dir ${runtimeImageDirectory}

    #     ensure_image() {
    #       if [ ! -f ${runtimeImageDirectory}/$2 ]; then
    #         qemu-img create -f qcow2 -o backing_fmt=qcow2 -o backing_file=$1 ${runtimeImageDirectory}/$2
    #       fi
    #     }

    #     ensure_image ${vmQcow2} vm.qcow2

    #     virsh_c() {
    #       virsh -c qemu:///session "$@"
    #     }

    #     virsh_c net-define ${networkXml}
    #     virsh_c net-autostart kali-network
    #     virsh_c net-start kali-network
    #     virsh_c define ${vmXml}
    #   '';
    # };

    # system.build.refreshXauthority = pkgs.writeShellApplication {
    #   name = "refresh-xauthority";
    #   runtimeInputs = with pkgs; [
    #     xorg.xauth
    #     gnused
    #   ];
    #   checkPhase = false;
    #   text = ''
    #     touch $XAUTHORITY
    #     xauth -i -f /host.Xauthority nlist | sed -e 's/^..../ffff/' | xauth -f $XAUTHORITY nmerge -
    #   '';
    # };

    # system.build.run = pkgs.writeShellApplication {
    #   name = "run";
    #   checkPhase = false;
    #   text = ''
    #     refresh-xauthority
    #     env $(cat /container-init/env.txt | grep DISPLAY) virt-manager -c qemu:///session
    #   '';
    # };

    # system.build.s = pkgs.writeShellApplication {
    #   name = "x";
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

    # networking.localCommands = ''
    #   ${config.system.build.s}/bin/*
    # '';

  };

}
