#!/usr/bin/env bash

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

[[ $# -eq 2 ]] || die "2 arguments expected, got $#"
assets_dir="$1"
channel="$2"
shift 2

kotasync_make() {
    local txz="$1"
    shift 1
    local new="${txz%.tar.xz}.kotasync"
    local old="ota/${txz%-v[0-9]*}-latest-nightly.kotasync"
    local cmd=(kotasync make)
    if [[ -e "${old}" ]]; then
        cmd+=(--reorder "${old}")
    fi
    cmd+=("${txz}" "${new}")
    container_exec "${cmd[@]}"
}

zsync_make() {
    local tgz="$1"
    shift 1
    local new="${tgz%.targz}.zsync"
    local cmd=(zsyncmake "${tgz}" -C -u "${tgz##*/}" -o "${new}")
    container_exec "${cmd[@]}"
}

latest_make() {
    local l="${2%-v[0-9]*}-latest-${channel}"
    case "$1" in
        link)
            echo -e "${ANSI_GREEN}echo $(quote "${2}") >$(quote "${l}")${ANSI_RESET}" 1>&2
            [[ -n "${DRY_RUN}" ]] || echo "$2" >"${l}"
            ;;
        copy)
            l+=".${2##*.}"
            run cp "${2}" "${l}"
            ;;
    esac
    if [[ "${channel}" == 'stable' ]]; then
        run cp "${l}" "${l/-latest-stable/-latest-nightly}"
    fi
}

# Fetch latest nightly kotasync files.
if out="$(gh release view --json assets --jq '.assets[].name | select(test("^koreader-.*-latest-nightly\\.kotasync$"))' ota)" && [[ -n "${out}" ]]; then
    run gh release download --dir="${assets_dir}/ota" --pattern='koreader-*-latest-nightly.kotasync' ota
    # shellcheck disable=SC2016
    onexit 'run rm -rf "${assets_dir}/ota"'
fi

# Start helper container.
container_start

# Generate kotasync / zsync individual files.
for a in "${assets_dir}"/koreader-{cervantes,kindle*,kobo*,pocketbook*,remarkable*,sony-prstux*}.{tar.xz,targz}; do
    [[ -e "${a}" ]] || continue
    # Generate.
    case "${a}" in
        *.tar.xz) t='kotasync' ;;
        *.targz) t='zsync' ;;
    esac
    "${t}_make" "${a}"
done

# Generate latest stable / nightly files.
for a in "${assets_dir}"/*; do
    [[ -e "${a}" ]] || continue
    case "${a}" in
        *-latest-*) ;; # Ignore those to make testing locally easier.
        *.apk | *.AppImage) latest_make link "${a}" ;;
        *.kotasync | *.zsync) latest_make copy "${a}" ;;
    esac
done

# vim: sw=4
