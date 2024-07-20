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

  scripts = with images;
    let
      xauthorityPath = "/home/x/Xauthority";

      refreshXauthority = writeScriptBin "refresh-xauthority" ''
        #!${runtimeShell}
        set -eu
        ${xauth}/bin/xauth -i -f /host.Xauthority nlist | ${gnused}/bin/sed -e 's/^..../ffff/' | ${xauth}/bin/xauth -f ${xauthorityPath} nmerge -
      '';

      interactScriptEnv = buildEnv {
        name = "env";
        paths = [
          coreutils
          gnugrep gnused
          iproute2 iptables
          bashInteractive
          nix cacert
          gosu
          qemu libvirt virt-manager
          refreshXauthority
        ] ++ (with pkgs; [
          strace
          inetutils
          ethtool
          # ...
        ]);
      };

      interactScript = writeScript "entry-continuation.sh" ''
        #!${runtimeShell}
        set -eu

        export PATH=${interactScriptEnv}/bin
        export MANPATH=${interactScriptEnv}/share/man
        export NIX_SSL_CERT_FILE=${interactScriptEnv}/etc/ssl/certs/ca-bundle.crt
        export XAUTHORITY=${xauthorityPath}

        bash
      '';

      dnsmasqConf = writeText "dhsmasq.conf" ''
        strict-order
        except-interface=lo
        bind-dynamic
        interface=vbr0
        dhcp-range=192.168.122.2,192.168.122.254,255.255.255.0
        dhcp-no-override
        dhcp-authoritative
        dhcp-lease-max=253
      '';

      entryScriptEnv = buildEnv {
        name = "env";
        paths = [
          coreutils
          iproute2 iptables
          gnugrep gnused
          qemu
        ];
      };

      entryScript = writeScript "entry.sh" ''
        #!${runtimeShell}
        set -eu

        export PATH=${entryScriptEnv}/bin:$PATH

        # validate and process input
        : "''${HOST_GID:=100}"
        : "''${HOST_UID:=1000}"
        [ -n "$KVM_GID" ]
        [ -z "''${AUDIO_GID+x}" ] || [ -n "$AUDIO_GID"} ]

        ${dockerTools.shadowSetup}

        groupadd -g "$HOST_GID" x
        useradd -u "$HOST_UID" -g "$HOST_GID" -m x
        groupadd nobody
        useradd -g nobody -M nobody

        ensure_group() {
          group=$1
          gid=$2
          id -G x | if ! grep -q $gid; then
            groupadd -g $gid $group
            usermod -aG $group x
          fi
        }
        ensure_group kvm $KVM_GID
        if [ -n "''${AUDIO_GID+x}" ]; then
          ensure_group audio $AUDIO_GID
        fi

        ensure_user_dir() {
          if [ ! -d $1 ]; then
            mkdir -p $1
            chown x:x $1
          fi
        }

        shared_base=/shared
        shared_dirs="$shared_base/container $shared_base/vm"
        ensure_user_dir $shared_base
        for d in $shared_dirs; do
          ensure_user_dir $d
        done

        ensure_user_dir ${runtimeImageDirectory}

        mkdir -p /run/wrappers/bin
        cp ${qemu}/libexec/qemu-bridge-helper /run/wrappers/bin
        chmod u+s /run/wrappers/bin/qemu-bridge-helper
        mkdir -p /etc/qemu
        touch /etc/qemu/bridge.conf

        br_addr="192.168.122.1"
        br_dev="vbr0"
        ip link add $br_dev type bridge stp_state 1 forward_delay 0
        ip link set $br_dev up
        ip addr add $br_addr/16 dev $br_dev
        iptables -t nat -F
        iptables -t nat -A POSTROUTING -s $br_addr/16 ! -o $br_dev -j MASQUERADE

        echo "allow $br_dev" >> /etc/qemu/bridge.conf

        mkdir -p /var/run # for /var/run/dnsmasq.pid
        mkdir -p /var/lib/misc # /var/lib/misc/dnsmasq.leases

        mkdir -p /etc/nix
        ln -s ${./nix.conf} /etc/nix/nix.conf

        ${dnsmasq}/bin/dnsmasq -C ${dnsmasqConf}

        ${gosu}/bin/gosu x ${entryScriptContinuation}
      '';

      entryScriptContinuation = writeScript "entry-continuation.sh" ''
        #!${runtimeShell}
        set -eu

        touch ${xauthorityPath}
        ${refreshXauthority}/bin/refresh-xauthority

        ensure_image() {
          if [ ! -f ${runtimeImageDirectory}/$2 ]; then
            ${qemu}/bin/qemu-img create -f qcow2 -o backing_fmt=qcow2 -o backing_file=$1 ${runtimeImageDirectory}/$2
          fi
        }

        ensure_image ${vmQcow2} vm.qcow2

        virsh_c() {
          ${libvirt}/bin/virsh -c qemu:///session "$@"
        }

        virsh_c net-define ${networkXml}
        virsh_c net-autostart kali-network
        virsh_c net-start kali-network
        virsh_c define ${vmXml}

        XAUTHORITY=${xauthorityPath} ${virt-manager}/bin/virt-manager -c qemu:///session

        echo "Initialization complete. Sleeping..."
        sleep inf
      '';

    in {
      inherit refreshXauthority;
      inherit entryScript interactScript;
    };

in rec {
  inherit images scripts;
  inherit (scripts) entryScript interactScript;

  nixos = import (pkgs.path + "/nixos") {
    configuration.imports = [
      ./config.nix
      {
        config.system.build.theseImages = images;
      }
    ];
  };

  inherit (nixos.config.system.build) containerInit;
}
