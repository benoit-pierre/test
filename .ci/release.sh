#!/usr/bin/env bash

declare -r DOCKER_IMAGE='koreader/nightswatcher:1.7.0'

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

die() {
    echo -e "${ANSI_RED}$*${ANSI_RESET}" 1>&2
    exit 1
}

run() {
    echo -e "::group::${ANSI_GREEN}$(printf '%q ' "$@")${ANSI_RESET}" 1>&2
    "$@" && code=0 || code=$?
    echo "::endgroup::" 1>&2
    return "${code}"
}

[[ $# -eq 1 ]] || "1 argument expected, got $#"
release_checkout="$1"
shift
# shellcheck disable=2016
[[ -n "${GH_REPO}" ]] || die '$GH_REPO is empty / not set'
# shellcheck disable=2016
[[ -n "${GH_TOKEN}" ]] || die '$GH_TOKEN is empty / not set'

# Setup git author.
run git -C "${release_checkout}" config user.name 'Github Actions'
run git -C "${release_checkout}" config user.email '<>'

# We can't rely on `$GITHUB_REF` since we may be called from the nightly workflow.
if tag="$(git describe --tag --exact-match --match='v[0-9]*')"; then
    stable=1
else
    tag='nightly'
    stable=''
    run git -C "${release_checkout}" tag -m '' -f nightly
fi
commit="$(git rev-parse HEAD)"

echo -e "${ANSI_BLUE}tag: ${tag}${ANSI_RESET}"
echo -e "${ANSI_BLUE}stable: ${stable:+yes}${stable:-no}${ANSI_RESET}"
echo -e "${ANSI_BLUE}target: ${target}${ANSI_RESET}"

# Update release repo tag.
run git -C "${release_checkout}" push -f origin "refs/tags/${tag}"

# Create release.
run gh release create ${stable:+--draft} --notes='.' ${stable:---prerelease} --target="${target}" --title="${tag}" "${tag}"

# new_commit="$(git rev-parse HEAD)"
# old_commit="$(gh release view "${tag}" --json targetCommitish | jq -r .targetCommitish || true)"
# if [[ -n "${old_commit}" ]]; then
#     old_commit="$(git rev-parse "${old_commit}")"
# fi

# create_release=0
# delete_release=0

# if [[ -z "${old_commit}" ]]; then
#     create_release=1
# elif [[ "${old_commit}" != "${new_commit}" ]]; then
#     if gh release view "${tag}" --json assets | jq --exit-status '.assets[]|.name|select(test("\\.kotasync$"))'; then
#         run gh release download "${tag}" --dir artifacts/old --pattern '*.kotasync'
#     fi
#     create_release=1
#     delete_release=1
# fi

# pushd artifacts/new || exit
# for a in *; do
#     case "${a}" in
#         koreader-*.AppImage)
#             arch="${a##*-}"
#             arch="${arch%.AppImage}"
#             printf %s "${a}" >"koreader-appimage-${arch}-latest-${channel}"
#             ;;
#         koreader-android-*.apk)
#             printf %s "${a}" >"${a%-v[0-9]*}-latest-${channel}"
#             ;;
#         koreader-kindlepw2-*.tar.xz)
#             kotasync_make "${a}" "${a%-v[0-9]*}-latest-${channel}.kotasync"
#             zsync_make "${a}" "${a%-v[0-9]*}-latest-${channel}.zsync"
#             ;;
#     esac
# done
# popd || exit

# if [[ "${delete_release}" -ne 0 ]]; then
#     run gh release delete --cleanup-tag --yes "${tag}"
# fi
# if [[ "${delete_release}" -ne 0 ]] && [[ "${create_release}" -ne 0 ]]; then
#     # Workaround for https://github.com/cli/cli/issues/8458…
#     sleep 1
# fi
# if [[ "${create_release}" -ne 0 ]]; then
#     run git tag --force "${tag}"
#     run git push -f "${GH_REPO}" "refs/tags/${tag}"
# fi
# artifacts=()
# for a in artifacts/new/*; do
#     case "${a##*/}" in
#         koreader-android-arm-*.apk)
#             a+='#Android ARM APK'
#             ;;
#         koreader-android-arm-*-${channel})
#             a+='#Android ARM OTA'
#             ;;
#         koreader-android-arm64-*.apk)
#             a+='#Android ARM64 APK'
#             ;;
#         koreader-android-arm64-*-${channel})
#             a+='#Android ARM64 OTA'
#             ;;
#         koreader-kindlepw2-*.tar.gz)
#             a+='#KindlePW2 TAR.GZ'
#             ;;
#         koreader-kindlepw2-*.tar.xz)
#             a+='#KindlePW2 TAR.XZ'
#             ;;
#         koreader-kindlepw2-*-${channel}.kotasync)
#             a+='#KindlePW2 OTA (KOTASync)'
#             ;;
#         koreader-kindlepw2-*-${channel}.zsync)
#             a+='#KindlePW2 OTA (ZSync)'
#             ;;
#         koreader-*-x86_64.AppImage)
#             a+='#Linux x86_64 AppImage'
#             ;;
#         koreader-appimage-*-${channel})
#             a+='#Linux x86_64 OTA'
#             ;;
#     esac
#     artifacts+=("${a}")
# done
# readarray -t artifacts < <(printf '%s\n' "${artifacts[@]}" | sort -t\# -k2)
# run gh release upload "${tag}" "${artifacts[@]}"

# # vim: sw=4
