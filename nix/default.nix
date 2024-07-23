let
  # HACK
  # nixpkgs = builtins.getFlake "nixpkgs/${(builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs.locked.rev}";
  nixpkgs = ../../kn/nixpkgs;
  pkgs = import nixpkgs {};
  this = pkgs.callPackage ./kali.nix {};
in this // { inherit pkgs; }
