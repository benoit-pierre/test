#!/usr/bin/env bash

set -e
set -o pipefail

# Avoid jumbled stderr / stdout outputs…
# exec 2>&1

declare -r ANSI_DIM="\033[2m"
declare -r ANSI_RED="\033[31;1m"
declare -r ANSI_GREEN="\033[32;1m"
# shellcheck disable=SC2034
declare -r ANSI_BLUE="\033[34;1m"
declare -r ANSI_RESET="\033[0m"

DRY_RUN="${DRY_RUN:-}"

quote() {
    [[ $# -ge 0 ]] || return 0
    printf '%q' "$1"
    shift
    [[ $# -eq 0 ]] || printf ' %q' "$@"
    printf '\n'
}

err() {
    echo -e "${ANSI_RED}$*${ANSI_RESET}" 1>&2
}

die() {
    err "$*"
    exit 1
}

run() {
    local code
    echo -e "::group::${ANSI_GREEN}$(quote "$@")${ANSI_RESET}" 1>&2
    if [[ -n "${DRY_RUN}" ]]; then
        code=0
    else
        "$@" && code=0 || code=$?
    fi
    if [[ "${code}" != 0 ]]; then
        err "Error: exit code ${code}"
    fi
    echo "::endgroup::" 1>&2
    return "${code}"
}

travis_retry() {
    local result=0
    local count=1
    set +e

    while [ ${count} -le 3 ]; do
        [ ${result} -ne 0 ] && {
            echo -e "\n${ANSI_RED}The command \"$*\" failed. Retrying, ${count} of 3.${ANSI_RESET}\n" >&2
        }
        "$@"
        result=$?
        [ ${result} -eq 0 ] && break
        count=$((count + 1))
        sleep 1
    done

    [ ${count} -gt 3 ] && {
        echo -e "\n${ANSI_RED}The command \"$*\" failed 3 times.${ANSI_RESET}\n" >&2
    }

    set -e
    return ${result}
}

ONEXIT=()

onexit() {
    ONEXIT+=("$@")
    local handler
    handler="echo -e '${ANSI_DIM}EXIT trap${ANSI_RESET}'$(printf " && %s" "${ONEXIT[@]}")"
    echo -e "${ANSI_DIM}trap ${handler@Q} EXIT${ANSI_RESET}"
    # shellcheck disable=SC2064
    trap "${handler}" EXIT
}

# Docker helpers. {{{

declare -r CONTAINER_IMAGE='koreader/nightswatcher:1.7.1'

container_start() {
    CONTAINER_ID="$(run docker run --detach --tty --volume="${PWD}:/work" --workdir=/work "${CONTAINER_IMAGE}" sh -c 'while true; do sleep 0.25; done')"
    # shellcheck disable=SC2016
    onexit 'run docker kill "${CONTAINER_ID}" && run docker rm "${CONTAINER_ID}"'
}

container_exec() {
    local code
    echo -e "::group::docker exec … ${ANSI_GREEN}$(quote "$@")${ANSI_RESET}" 1>&2
    if [[ -n "${DRY_RUN}" ]]; then
        code=0
    else
        docker exec --tty "${CONTAINER_ID}" "$@" && code=0 || code=$?
    fi
    if [[ "${code}" != 0 ]]; then
        err "Error: exit code ${code}"
    fi
    echo "::endgroup::"
    return "${code}" 1>&2
}

# }}}

echo -e "${ANSI_BLUE}$(quote "$0" "$@")${ANSI_RESET}" 1>&2
trap 'err "Error: exit code $?"' ERR
