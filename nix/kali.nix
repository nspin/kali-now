{ stdenv, lib, runCommand, writeText, writeScript, writeScriptBin, runtimeShell, buildEnv
, fetchurl
, nix, cacert
, qemu, libvirt, virt-manager, libguestfs-with-appliance, dnsmasq
, gosu, xauth, dockerTools
, coreutils, gnugrep, gnused, iproute2, iptables
, bashInteractive
, pkgs
}:

let
  enablePersistentImage = true;
  memoryMegabytes = 4096;
  persistenceSize = "64G";
in

let
  runtimeImageDirectory = if enablePersistentImage then "/shared/container" else "/images";

  images =
    let
      iso = fetchurl {
        url = "https://cdimage.kali.org/kali-2024.2/kali-linux-2024.2-live-amd64.iso";
        hash = "sha256-jOcbFihfiHG5jj8hVThvEjwv3KkCUzDA0TSfRHmOZek=";
      };

      vmQcow2 = runCommand "kali-live-persistent.qcow2" {
        nativeBuildInputs = [ qemu libguestfs-with-appliance ];
      } ''
        img=new.qcow2

        qemu-img create -f qcow2 -o backing_fmt=raw -o backing_file=${iso} $img
        qemu-img resize -f qcow2 $img +${persistenceSize}

        last_byte=$(
          guestfish add $img : run : part-list /dev/sda | \
            sed -rn 's,^  part_end: ([0-9]+)$,\1,p' | sort | tail -n 1
        )

        sector_size=$(
          guestfish add $img : run : blockdev-getss /dev/sda
        )

        first_sector=$(expr $(expr $last_byte + 1) / $sector_size)

        cat > persistence.conf <<EOF
        / union
        EOF

        guestfish <<EOF
        add $img
        run
        part-add /dev/sda primary $first_sector -1
        mkfs ext4 /dev/sda3 label:persistence
        mount /dev/sda3 /
        copy-in persistence.conf /
        EOF

        mv $img $out
      '';

      vmXmlRaw = ./vm.xml;

      vmXml = runCommand "vm.xml" {} ''
        sed \
          -e 's,@runtimeImagePath@,${runtimeImageDirectory}/vm.qcow2,' \
          -e 's,@memoryKilobytes@,${toString (memoryMegabytes * 1024)},' \
          < ${vmXmlRaw} > $out
      '';

      networkXml = writeText "network.xml" ''
        <network>
          <name>kali-network</name>
          <forward mode='bridge'/>
          <bridge name='vbr0' />
        </network>
      '';

    in {
      inherit iso;
      inherit vmQcow2 vmXml networkXml;
      inherit runtimeImageDirectory;
    };

in rec {
  inherit images;

  nixos = import (pkgs.path + "/nixos") {
    specialArgs = {
      inherit images;
    };
    configuration.imports = [
      ./config.nix
      # ./minimal-config.nix
    ];
  };

  inherit (nixos.config.system.build) toplevel containerInit;
}
