#!/bin/bash


DO_STOP=false
DO_DOWNLOAD=true
CONTAINER_NAME=kestrel_build
CONTAINER_TAG=ngp/build:latest
PPWD="$(cd "$(dirname "$0")" ; pwd)"

while (( $# > 0 )) ; do
    ARG="$1"
    [ "$ARG" = "--restart" ] && DO_STOP=true && shift && continue
    [ "$ARG" = "--download" ] && DO_DOWNLOAD=true && shift && continue
    [ "$ARG" = "--no-download" ] && DO_DOWNLOAD=false && shift && continue
    [ "$ARG" = "--alt" ] && CONTAINER_TAG=ngp/build:alt && DO_DOWNLOAD=false && shift && continue
    break
done

export KESTREL_GIT_DIR=$HOME/Development/scorpius/project/cple/sg_cple1

# ------------------------------------------------------------------------------------------- Action

HOST_WORKDIR="$(readlink -f ${PWD})"
RELATIVE_WORKDIR="${HOST_WORKDIR##${KESTREL_GIT_DIR}}"

if [[ "${HOST_WORKDIR}" == "${RELATIVE_WORKDIR}" ]]; then
    CONTAINER_WORKDIR="${KESTREL_GIT_DIR}"
else
    CONTAINER_WORKDIR="${PWD}"
fi

# ------------------------------------------------------------------------------------------ Actions

ensure_file_exists()
{
    # If '$FILE' doesn't exist, then "docker -v $FILE:..." will create the file
    # as a directory, and mount it in the docker container as a directory.
    local FILE="$1"
    shift
    if [ -d "$FILE" ] ; then
        echo "ERROR: expected plain text file '$FILE', but found directory" 1>&2
	exit 1
    fi
    if [ ! -f "$FILE" ] ; then
        touch "$FILE"
    fi
    if [ ! -f "$FILE" ] ; then
        echo "ERROR: file not found: '$FILE', and failed to create it" 1>&2
	exit 1
    fi
}

is_container_running()
{
    if [[ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || true)" == "true" ]]; then
	return 0
    else
	return 1
    fi
}

do_download()
{
    docker pull ngp-docker-release-local.artifactory-ren.broadcom.net/ngp/build:latest
    docker tag ngp-docker-release-local.artifactory-ren.broadcom.net/ngp/build:latest ngp/build:latest
}

do_start()
{
    if is_container_running; then
	return 0
    fi
    mkdir -p ${HOME}/.cache/bazel
    mkdir -p ${HOME}/.cache/bazelisk
    mkdir -p ${HOME}/.cache/kestrel_crashes
    if [[ -z ${USE_LOCAL_CONTAINER+no} ]] && [ "$DO_DOWNLOAD" = true ] ; then
	do_download
    fi
    ensure_file_exists ${HOME}/.gdbinit 
    ensure_file_exists ${HOME}/.netrc
    ensure_file_exists ${HOME}/.gitconfig
    docker run -d --init --security-opt seccomp=unconfined --cap-add=SYS_PTRACE --cap-add=NET_ADMIN \
	--rm --name "${CONTAINER_NAME}" --net=host \
	-e USER_HOME="${HOME}" \
	-e USER_UID="$(id -u)" \
	-e USER_GID="$(id -g)" \
	-e DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)" \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v ${KESTREL_GIT_DIR}:${KESTREL_GIT_DIR} \
	-v "${HOME}/.cache/bazel":"${HOME}/.cache/bazel" \
	-v "${HOME}/.cache/bazelisk":"${HOME}/.cache/bazelisk" \
	-v "${HOME}/.gdbinit:${HOME}/.gdbinit" \
	-v "${HOME}/.netrc:${HOME}/.netrc" \
	-v "${HOME}/.gitconfig:${HOME}/.gitconfig" \
	-v "${HOME}/.cache/kestrel_crashes:/var/crash" \
	-w "${CONTAINER_WORKDIR}" \
	"$CONTAINER_TAG"

    # Have to run a benign command so that when the user wants a shell the user to uid mapping is correct
    docker exec -u build -it -w "${CONTAINER_WORKDIR}" "${CONTAINER_NAME}" bash -c "echo -ne"
}

do_stop()
{
    docker stop "${CONTAINER_NAME}"
}

do_exec()
{
    do_start
    docker exec -u build -it -w "${CONTAINER_WORKDIR}" "${CONTAINER_NAME}" bash -c "$*"
}

do_shell()
{
    do_exec bash -l
}



# ------------------------------------------------------------------------------------------ Execute

cp $HOME/.bashrc /tmp/.profile

[ "$DO_STOP" = "true" ] && do_stop || true
do_exec echo kb container is running

docker cp "$HOME/Bin"     "kestrel_build:/home/BRCMLTD/$USER"
docker cp "$HOME/.ssh"    "kestrel_build:/home/BRCMLTD/$USER"
docker cp "$HOME/.docker" "kestrel_build:/home/BRCMLTD/$USER"
docker cp "/tmp/.profile" "kestrel_build:/home/BRCMLTD/$USER"

rm -f /tmp/.profile
# docker inspect kestrel_build | grep WorkingDir
# kb shell

do_shell

