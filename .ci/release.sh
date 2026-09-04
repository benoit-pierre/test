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
    draft=1
    prerelease=
else
    tag='nightly'
    draft=
    prerelease=1
fi

target="$(git -C "${release_checkout}" rev-parse HEAD)"

if out="$(gh release view "${tag}" --json 'assets' | jq -r '.assets[].name')"; then
    readarray -t old_assets <<<"${out}"
    mode='edit'
else
    old_assets=()
    mode='create'
fi

echo -e "${ANSI_BLUE}mode      : ${mode}${ANSI_RESET}"
echo -e "${ANSI_BLUE}tag       : ${tag}${ANSI_RESET}"
echo -e "${ANSI_BLUE}target    : ${target}${ANSI_RESET}"
echo -e "${ANSI_BLUE}draft     : ${draft:-0}${ANSI_RESET}"
echo -e "${ANSI_BLUE}prerelease: ${prerelease:-0}${ANSI_RESET}"

# Label & sort assets.
out="$(jq --raw-output --from-file .ci/release.label.jq --null-input --args "${assets_dir}"/*)"
readarray -t assets <<<"${out}"

# Setup git author.
run git -C "${release_checkout}" config user.name 'Github Actions'
run git -C "${release_checkout}" config user.email '<>'

# Update release repo tag.
run git -C "${release_checkout}" tag -m '' -f "${tag}"
run git -C "${release_checkout}" push -f origin "refs/tags/${tag}"

# Create / update release.
case "${mode}" in
    create) run gh release create ${draft:+--draft} ${prerelease:+--prerelease} --target="${target}" --title="${tag}" "${tag}" ;;
    edit) run gh release edit --target="${target}" "${tag}" ;;
esac

# Upload assets.
run gh release upload --clobber "${tag}" "${assets[@]}"

# Cleanup left-overs from previous version.
out="$(comm -23 <(printf '%s\n' "${old_assets[@]}" | sort) <(printf '%s\n' "${assets[@]}" | sed 's,^.*/,,;s,#.*$,,;' | sort))"
if [[ -n "${out}" ]]; then
    readarray -t old_assets <<<"${out}"
    for a in "${old_assets[@]}"; do
        run gh release delete-asset -y "${tag}" "${a}"
    done
fi

# Trigger repo "new release" dispatch.
run gh api \
    --method POST \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2026-03-10' \
    "/repos/${GH_REPO}/dispatches" \
    -f 'event_type=new_release' \
    -F "client_payload[release]=${tag}"

# vim: sw=4
