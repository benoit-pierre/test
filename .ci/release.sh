#!/usr/bin/env bash

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

[[ $# -eq 2 ]] || "2 argument expected, got $#"
assets_dir="$1"
release_checkout="$2"
shift 2

# We can't rely on `$GITHUB_REF` since we may be called from the nightly workflow.
if tag="$(git -C "${release_checkout}" describe --tag --exact-match --match='v[0-9]*')"; then
    channel='stable'
    draft=1
    prerelease=
else
    channel='nightly'
    tag='ota'
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

if [[ "${tag}" = 'ota' ]]; then
    "${CI_DIR}/ota.sh" "${assets_dir}" "${channel}"
fi

# Label & sort assets.
shopt -s extglob
out="$(jq --raw-output --from-file .ci/release.label.jq --null-input --args "${assets_dir}"/*)"
shopt -u extglob
readarray -t assets <<<"${out}"

# Setup git author.
run git -C "${release_checkout}" config user.name 'Github Actions'
run git -C "${release_checkout}" config user.email '<>'

# Update release repo tag.
run git -C "${release_checkout}" tag -m '' -f "${tag}"
run git -C "${release_checkout}" push -f origin "refs/tags/${tag}"

# Create / update release.
cmd=(gh release "${mode}" --target="${target}")
if [[ "${mode}" = 'create' ]]; then
    cmd+=(${draft:+--draft} ${prerelease:+--prerelease} --title="${tag}")
fi
cmd+=("${tag}")
run "${cmd[@]}"

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

# vim: sw=4
