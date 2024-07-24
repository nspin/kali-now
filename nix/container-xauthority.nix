{ lib
, writeShellApplication
, xauth
}:

writeShellApplication {
  name = "container-xauthority";
  runtimeInputs = [
    xauth
  ];
  checkPhase = false;
  text = builtins.readFile ./container-xauthority.sh;
}
