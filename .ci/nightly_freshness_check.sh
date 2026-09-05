#!/usr/bin/env bash

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

fresh='true'

tag_name="$(git describe --tag --exact-match --match='v[0-9]*' 2>/dev/null)" || tag_name='nightly'
new_target="$(git rev-parse HEAD)"
old_target="$(gh release view --json targetCommitish --template '{{ .targetCommitish }}' "${tag_name}" || true)"

if [[ "${new_target}" = "${old_target}" ]]; then
    fresh=
fi

echo "fresh=${fresh}"
