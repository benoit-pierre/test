#!/usr/bin/env bash

declare -r DOCKER_IMAGE='koreader/nightswatcher:1.7.1'

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

[[ $# -eq 2 ]] || "2 arguments expected, got $#"
assets_dir="$1"
channel="$2"
shift 2

CONTAINER_ID="$(run docker run --detach --tty --volume="$(realpath "${assets_dir}"):/work" --workdir=/work "${DOCKER_IMAGE}" sh -c 'while true; do sleep 0.25; done')"
trap 'run docker rm --force "${CONTAINER_ID}"' EXIT

container_exec() {
    local code
    echo -e "::group::docker exec … ${ANSI_GREEN}$(printf '%q ' "${@/#█:*/████████}")${ANSI_RESET}" 1>&2
    if [[ -n "${DRY_RUN}" ]]; then
        code=0
    else
        docker exec --tty "${CONTAINER_ID}" "${@#█:}" && code=0 || code=$?
    fi
    echo "::endgroup::"
    return "${code}" 1>&2
}

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
    local cmd=(zsyncmake "${tgz}" -C -u "${tgz}" -o "${new}")
    container_exec "${cmd[@]}"
}

latest_make() {
    local l="${2%-v[0-9]*}-latest-${channel}"
    case "$1" in
        link)
            run sh -c 'echo "$1" >"$2"' -- "${2}" "${l}"
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
    trap 'run rm -rf "${assets_dir}/ota"' EXIT
fi

echo -e "${ANSI_GREEN}pushd assets_dir${ANSI_RESET}" 1>&2
pushd "${assets_dir}" >/dev/null || exit

# Sign APKs.
if [[ -n "${APK_SIGN_KEY_ALIAS}" ]] && [[ -n "${APK_SIGN_KEY_PASS}" ]] && [[ -n "${APK_SIGN_STORE_BASE64}" ]] && [[ -n "${APK_SIGN_STORE_PASS}" ]]; then (
    set +x
    # Setup temporary store.
    apk_sign_store="$(mktemp --tmpdir=. -t apk_sign_store.XXXXXXXXXX)"
    trap 'rm -f "${apk_sign_store}"' EXIT
    base64 -d >"${apk_sign_store}" <<<"${APK_SIGN_STORE_BASE64}"
    # Signing helper.
    apk_sign_cmd=(
        uber-apk-signer
        --verbose
        --overwrite
        --ks "█:${apk_sign_store}"
        --ksAlias "█:${APK_SIGN_KEY_ALIAS}"
        --ksKeyPass "█:${APK_SIGN_KEY_PASS}"
        --ksPass "█:${APK_SIGN_STORE_PASS}"
        --allowResign
        --apks
    )
    # Sign APKS.
    for a in koreader-*.apk; do
        [[ -e "${a}" ]] || continue
        # Sign.
        container_exec "${apk_sign_cmd[@]}" "${a}"
        # And create corresponding latest file.
        latest_make link "${a}"
    done
); fi

# Generate kotasync / zync individual files.
for a in koreader-{cervantes,kindle*,kobo*,pocketbook*,remarkable*,sony-prstux*}.{tar.xz,targz}; do
    [[ -e "${a}" ]] || continue
    # Generate.
    case "${a}" in
        *.tar.xz) t='kotasync' ;;
        *.targz) t='zsync' ;;
    esac
    "${t}_make" "${a}"
    # And create corresponding latest file.
    latest_make copy "${a%.tar*}.${t}"
done

echo -e "${ANSI_GREEN}popd -${ANSI_RESET}" 1>&2
popd >/dev/null || exit

# vim: sw=4
