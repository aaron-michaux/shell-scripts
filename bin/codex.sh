#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR=
while (( $# > 0 )) ; do
    ARG="$1"
    [ "$ARG" = "--" ] && break
    shift
    [ "$PROJECT_DIR" = "" ] && PROJECT_DIR="$ARG" && continue
    echo "Must pass '--' before passing arguments through to the codex wrapper" 1>&2
    exit 1
done

[ "$PROJECT_DIR" = "" ] && PROJECT_DIR="$(pwd)"
[ ! -d "$PROJECT_DIR" ] && echo "directory not found: $PROJECT_DIR"
PROJECT_DIR="$(realpath "$PROJECT_DIR")"

NAME="codex-$(basename "$(pwd)")"

cd "$PROJECT_DIR"
if [ "$(git rev-parse --is-inside-work-tree)" != "true" ] ; then
    echo "Not in a git-repo; aborting." 2>&1 && exit 1
fi

if docker ps --filter "name=^$NAME\$" --format '{{.Names}}' | grep -q . ; then
    echo "Container already running, name: $NAME; aborting." 2>&1 && exit 1
fi

# ------------------- Persistent directories
persistent_dirs() {
    cat <<EOF
.config/codex           rw
.local/share/codex      rw
.cache/codex            rw
.codex                  rw
.agents                 ro
EOF
}
persistent_dirs | while read V P ; do mkdir -p "$HOME/$V" ; done

persistent_dir_args() {
    persistent_dirs | while read V P ; do
        echo "-v $HOME/$V:$CODEX_HOME/$V:$P"
    done
}

# ------------------- Temp Directories
CODEX_HOME=/home/codex
CODEX_TEMP="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"
CODEX_TEMP="${CODEX_TEMP%/}"
trap cleanup EXIT
cleanup() {
    rm -rf "$CODEX_TEMP"
}

temp_dirs() {
    cat <<EOF
/tmp             /tmp
$CODEX_HOME      $CODEX_HOME
/workspace-venv  /workspace/.venv
EOF
}

mkdir -p "$CODEX_TEMP/$CODEX_HOME/.local/state"
touch "$CODEX_TEMP/$NAME"

temp_dirs | while read V D ; do mkdir -p "$CODEX_TEMP/$V" ; done

temp_dir_args() {
    temp_dirs | while read V D ; do
        echo "-v $CODEX_TEMP/$V:$D:rw"
    done
}

exec docker run --rm -it \
  --name "$NAME" \
  --user "$(id -u):$(id -g)" \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --pids-limit=512 \
  --memory=8g \
  --cpus=12 \
  --read-only \
  -e HOME=$CODEX_HOME \
  -e EDITOR=vi \
  $(temp_dir_args) \
  $(persistent_dir_args) \
  -v "$PROJECT_DIR:/workspace:rw" \
  -w /workspace \
  codex-sandbox \
  /workspace "$@"

