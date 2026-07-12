#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR=
while (( $# > 0 )) ; do
    ARG="$1"
    [ "$ARG" = "--" ] && break
    shift
    [ "$PROJECT_DIR" = "" ] && PROJECT_DIR="$ARG" && continue
    echo "Must pass '--' before passing arguments through to the opencode wrapper" 1>&2
    exit 1
done

[ "$PROJECT_DIR" = "" ] && PROJECT_DIR="$(pwd)"
[ ! -d "$PROJECT_DIR" ] && echo "directory not found: $PROJECT_DIR"
PROJECT_DIR="$(realpath "$PROJECT_DIR")"

NAME="sandbox-$(basename "$(pwd)")"

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
.config/opencode        rw
.local/share/opencode   rw
.cache/opencode         rw
.opencode               rw
.agents                 ro
EOF
}
persistent_dirs | while read V P ; do mkdir -p "$HOME/$V" ; done

persistent_dir_args() {
    persistent_dirs | while read V P ; do
        echo "-v $HOME/$V:$OPENCODE_HOME/$V:$P"
    done
}

# ------------------- Temp Directories
OPENCODE_HOME=/home/opencode
OPENCODE_TEMP="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"
OPENCODE_TEMP="${OPENCODE_TEMP%/}"
trap cleanup EXIT
cleanup() {
    rm -rf "$OPENCODE_TEMP"
}

temp_dirs() {
    cat <<EOF
/tmp             /tmp
$OPENCODE_HOME   $OPENCODE_HOME
/workspace-venv  /workspace/.venv
EOF
}

mkdir -p "$OPENCODE_TEMP/$OPENCODE_HOME/.local/state"
touch "$OPENCODE_TEMP/$NAME"

temp_dirs | while read V D ; do mkdir -p "$OPENCODE_TEMP/$V" ; done

temp_dir_args() {
    temp_dirs | while read V D ; do
        echo "-v $OPENCODE_TEMP/$V:$D:rw"
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
  -e HOME=$OPENCODE_HOME \
  -e EDITOR=vi \
  $(temp_dir_args) \
  $(persistent_dir_args) \
  -v "$PROJECT_DIR:/workspace:rw" \
  -w /workspace \
  opencode-sandbox \
  /workspace "$@"

