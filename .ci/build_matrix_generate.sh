#!/usr/bin/env bash

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

[[ $# -ge 1 ]] || die "at least one argument expected, got $#"

jobs_file="${0%/*}/build_jobs.yml"
jq_script="${0%/*}/build_matrix_generate.jq"

yq=("$( (which yq4 || which yq) 2>/dev/null)")
if "${yq[@]}" --yaml-fix-merge-anchor-to-spec >/dev/null 2>&1; then
    yq+=(--yaml-fix-merge-anchor-to-spec)
fi

json="$("${yq[@]}" --output-format=json . "${jobs_file}")"

# Debug.
jobs="$(jq --compact-output --from-file "${jq_script}" --args "$@" <<<"${json}")"
{
    printf 'jobs: '
    <<<"${jobs}" jq --color-output --sort-keys
    printf 'jobs (expanded): '
    <<<"${jobs}" jq --color-output --sort-keys 'to_entries | map(.value = (.value | fromjson)) | from_entries'
}

# Outputs.
printf '%s=%s\n' 'jobs' "${jobs}" >>"${GITHUB_OUTPUT:-/proc/self/fd/1}"

# vim: sw=4
