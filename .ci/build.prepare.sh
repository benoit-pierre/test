#!/bin/bash

set -eo pipefail

[[ $# -ge 1 ]]

jobs_file="${0%/*}/build.jobs.yml"
jq_script="${0%/*}/build.prepare.jq"

yq=("$( (which yq4 || which yq) 2>/dev/null)")
if "${yq[@]}" --yaml-fix-merge-anchor-to-spec >/dev/null 2>&1; then
    yq+=(--yaml-fix-merge-anchor-to-spec)
fi

json="$("${yq[@]}" --output-format=json . "${jobs_file}")"

jobs="$(jq --compact-output --from-file "${jq_script}" --args "$@" <<<"${json}")"
{
    printf '%s jobs: ' "${variant}"
    jq --color-output --sort-keys <<<"${jobs}"
} 1>&2
printf '%s=%s\n' 'jobs' "${jobs}"

# vim: sw=4
