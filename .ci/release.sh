#!/usr/bin/env bash

declare -r DRY_RUN=

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

die() {
    echo -e "${ANSI_RED}$*${ANSI_RESET}" 1>&2
    exit 1
}

run() {
    echo -e "::group::${ANSI_GREEN}$(printf '%q ' "$@")${ANSI_RESET}" 1>&2
    if [[ -n "${DRY_RUN}" ]]; then
        code=0
    else
        "$@" && code=0 || code=$?
    fi
    echo "::endgroup::" 1>&2
    return "${code}"
}

[[ $# -eq 2 ]] || "2 argument expected, got $#"
assets_dir="$1"
release_checkout="$2"
shift 2

# shellcheck disable=2016
[[ -n "${GH_REPO}" ]] || die '$GH_REPO is empty / not set'
# shellcheck disable=2016
[[ -n "${GH_TOKEN}" ]] || die '$GH_TOKEN is empty / not set'

# We can't rely on `$GITHUB_REF` since we may be called from the nightly workflow.
if tag="$(git -C "${release_checkout}" describe --tag --exact-match --match='v[0-9]*')"; then
    stable=1
else
    tag='nightly'
    stable=''
fi

target="$(git -C "${release_checkout}" rev-parse HEAD)"

if out="$(gh release view "${tag}" --json 'assets' | jq -r '.assets[].name')"; then
    readarray -t old_assets <<<"${out}"
    mode='edit'
else
    old_assets=()
    mode='create'
fi

echo -e "${ANSI_BLUE}mode  : ${mode}${ANSI_RESET}"
echo -e "${ANSI_BLUE}stable: ${stable:+yes}${stable:-no}${ANSI_RESET}"
echo -e "${ANSI_BLUE}tag   : ${tag}${ANSI_RESET}"
echo -e "${ANSI_BLUE}target: ${target}${ANSI_RESET}"

assets=()
for a in "${assets_dir}"/*; do
    case "${a##*/}" in
        koreader-android-arm-*.apk) a+='#Android ARM APK' ;;
        koreader-android-arm64-*.apk) a+='#Android ARM64 APK' ;;
        koreader-kindlepw2-*.tar.gz) a+='#KindlePW2 TAR.GZ' ;;
        koreader-kindlepw2-*.tar.xz) a+='#KindlePW2 TAR.XZ' ;;
        koreader-kindlepw2-*.zip) a+='#KindlePW2 ZIP' ;;
        koreader-*-x86_64.AppImage) a+='#Linux x86_64 AppImage' ;;
    esac
    assets+=("${a}")
done
readarray -t assets < <(printf '%s\n' "${assets[@]}" | sort -t\# -k2)

# Setup git author.
run git -C "${release_checkout}" config user.name 'Github Actions'
run git -C "${release_checkout}" config user.email '<>'

# Update release repo tag.
run git -C "${release_checkout}" tag -m '' -f "${tag}"
run git -C "${release_checkout}" push -f origin "refs/tags/${tag}"

# Create / update release.
run gh release "${mode}" ${stable:+--draft} --notes='.' ${stable:---prerelease} --target="${target}" --title="${tag}" "${tag}"

# Upload assets.
run gh release upload --clobber "${tag}" "${assets[@]}"

# Cleanup left-overs from previous version.
out="$(comm -23 <(printf '%s\n' "${old_assets[@]}" | sort) <(printf '%s\n' "${assets[@]}" | sed 's,^.*/,,;s,#.*$,,;' | sort))"
readarray -t old_assets <<<"${out}"
for a in "${old_assets[@]}"; do
    run gh release delete-asset -y "${tag}" "${a}"
done

# vim: sw=4
