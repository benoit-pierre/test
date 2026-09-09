#!/usr/bin/env bash

set -e
set -o pipefail

# Avoid jumbled stderr / stdout outputs…
exec 2>&1

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
    echo -e "::group::${ANSI_GREEN}$(quote "${@/#█:*/████████}")${ANSI_RESET}" 1>&2
    if [[ -n "${DRY_RUN}" ]]; then
        code=0
    else
        "${@#█:}" && code=0 || code=$?
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

echo -e "${ANSI_BLUE}$(quote "$0" "$@")${ANSI_RESET}" 1>&2
trap 'err "Error: exit code $?"' ERR
