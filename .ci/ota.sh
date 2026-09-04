#!/usr/bin/env bash

declare -r DOCKER_IMAGE='koreader/nightswatcher:1.7.0'

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

[[ $# -eq 2 ]] || "2 arguments expected, got $#"
assets_dir="$1"
channel="$2"
shift 2

CONTAINER_ID="$(run docker run --detach --tty --volume="${assets_dir}:/work" --workdir=/work "${DOCKER_IMAGE}" sh -c 'while true; do sleep 0.25; done')"
trap 'run docker kill "${CONTAINER_ID}"' EXIT

container_exec() {
    echo -e "::group::docker exec … ${ANSI_GREEN}$(printf '%q ' "$@")${ANSI_RESET}" 1>&2
    if [[ -n "${DRY_RUN}" ]]; then
        code=0
    else
        docker exec --tty "${CONTAINER_ID}" "$@" && code=0 || code=$?
    fi
    echo "::endgroup::"
    return "${code}" 1>&2
}

kotasync_make() {
    txz="$1"
    shift 1
    new_kotasync="${txz%.tar.xz}.kotasync"
    old_kotasync="old/${txz%-v[0-9]*}-latest-nightly.kotasync"
    cmd=(kotasync make)
    if [[ -e "${old_kotasync}" ]]; then
        cmd+=(--reorder "${old_kotasync}")
    fi
    cmd+=("${txz}" "${new_kotasync}")
    container_exec "${cmd[@]}"
}

zsync_make() {
    tgz="$1"
    shift 1
    cmd=(zsyncmake "new/${tgz}" -C -u "${tgz}" -o "new/${tgz%.targz}.zsync")
    container_exec "${cmd[@]}"
}

if out="$(gh release view --json assets --jq '.assets[].name | select(test("^koreader-.*-latest-nightly\\.kotasync$"))' ota)" && [[ -n "${out}" ]]; then
    run mkdir -p "${assets_dir}/old"
    run gh release download --directory="${assets_dir}/old" --pattern='koreader-*-latest-nightly.kotasync' ota
fi

# shellcheck disable=2164
pushd "${assets_dir}"
for a in koreader-{cervantes,kindle*,kobo*,pocketbook*,remarkable*,sony-prstux*}.{tar.xz,targz}; do
    [[ -e "${a}" ]] || continue
    case "${a}" in
        *.tar.xz) kotasync_make "${a}" ;;
        *.targz) zsync_make "${a}" ;;
    esac
done
# shellcheck disable=2164
popd

run rm -rf "${assets_dir}/old"

for a in "${assets_dir}"/*.{kotasync,zsync}; do
    [[ -e "${a}" ]] || continue
    run cp "${a}" "${a%-v[0-9]*}-lastest-${channel}.${a##*.}"
    if [[ "${channel}" == 'stable' ]]; then
        run cp "${a}" "${a%-v[0-9]*}-lastest-nightly.${a##*.}"
    fi
done

# vim: sw=4
