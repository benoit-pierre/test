def match(filters):
  . as $str | any(filters.[]; . as $f | $str | test("^" + $f + "$"))
;

# Isolate sets & jobs, setup initial filters.
(
 to_entries | {
  "sets": [.[] | .value = (.value | flatten) | select(.value[0] | strings)] | from_entries,
  "jobs": [.[] | select(.value[0] | objects)] | from_entries,
  "filters": $ARGS.positional,
 }
) as $s1 #| debug
# Update filters with matching sets.
| $s1 | .filters += (
  [
    $s1.sets | to_entries.[]
    | select(.key | match($s1.filters))
    | .value
  ] | flatten | unique
) | . as $s2 | $s2 #| debug
# And filter-out matching jobs…
| $s2.jobs | to_entries #| debug
| map(.value = (
  [
    .value.[]
    | select(.id | match($s2.filters))
    # …updating optional fields.
    | .cache=(.cache // .id)
    | .target=(.target // .id)
    | .check_ffi_cdecls=(.check_ffi_cdecls // true)
  ]
  # NOTE: we replace an empty job array by an empty string.
  # | if . == [] then "" else . end
)) | . as $s3 | $s3 #| debug
| map(.value =
  ({
    "if": ["!cancelled()", .value != [] | tostring],
    "name": .key,
    "needs": ["prepare"],
    "uses": "./.github/workflows/build.matrix.yml",
    "with": {
      "jobs": (.value | tojson),
      "fail_fast": $fail_fast,
      "all_artifacts": $all_artifacts,
      "test": $test
    }
  })
  | .value."if" = (.value."if" | join(" && "))
)
| from_entries

# vim: sw=2
