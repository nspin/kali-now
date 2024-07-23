#!/bin/sh

set -eu -o pipefail

contents() {
  xauth -i nextract - $DISPLAY | sed -e 's/^..../ffff/'
}

merge_from_env() {
  printf '%s' "$XAUTHORITY_CONTENTS" | xauth -q nmerge -
}

subcommand="$1"
shift

case "$subcommand" in

  contents)
    contents
    ;;

  merge-from-env)
    merge_from_env
    ;;

  env-host)
    exec env XAUTHORITY_CONTENTS="$(contents)" "$@"
    ;;

  env-container)
    merge_from_env
    exec "$@"
    ;;

  *)
    echo "unrecognized subcommand: $subcommand" >&2
    exit 1
    ;;
esac
