#!/bin/bash

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

[[ $# -ge 1 ]] || "at least one argument expected, got $#"

jobs_file="${0%/*}/build.jobs.yml"
jq_script="${0%/*}/build.prepare.jq"

yq=("$( (which yq4 || which yq) 2>/dev/null)")
if "${yq[@]}" --yaml-fix-merge-anchor-to-spec >/dev/null 2>&1; then
    yq+=(--yaml-fix-merge-anchor-to-spec)
fi

json="$("${yq[@]}" --output-format=json . "${jobs_file}")"

jobs="$(jq --compact-output --from-file "${jq_script}" --args "$@" <<<"${json}")"
{
    printf 'jobs: '
    <<<"${jobs}" jq --color-output --sort-keys
    printf 'jobs (partial expansion): '
    <<<"${jobs}" jq --color-output --sort-keys 'to_entries | map(.value = (.value | fromjson)) | from_entries'
    printf 'jobs (full expansion): '
    <<<"${jobs}" jq --color-output --sort-keys '{ "emulator": .emulator | fromjson, "platform": .platform | fromjson | map(.jobs = (.jobs | fromjson)) }' <<<"${jobs}"
} 1>&2
# Output
printf '%s=%s\n' 'jobs' "${jobs}"

# vim: sw=4
