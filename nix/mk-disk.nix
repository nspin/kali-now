{ lib
, runCommand
, fetchurl
, qemu, libguestfs-with-appliance, dnsmasq
}:

{ persistenceSize
}:

let
  iso = fetchurl {
    url = "https://cdimage.kali.org/kali-2024.2/kali-linux-2024.2-live-amd64.iso";
    hash = "sha256-jOcbFihfiHG5jj8hVThvEjwv3KkCUzDA0TSfRHmOZek=";
  };
in

runCommand "kali-live-persistent.qcow2" {
  nativeBuildInputs = [ qemu libguestfs-with-appliance ];
  passthru = {
    inherit iso;
  };
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
''
