include "assets_parse";

[$ARGS.positional[] | asset_parse]
# Sort by version (decreasing, tie-break on platform & extension).
| sort_by(.sort_version)
# Label.
| .[] | .file + "#" + ([
  if .commit_number then .base_version + "-" + .commit_number else .base_version end,
  .platform_name,
  "(" + .extension + ")"
] | join(" "))

# vim: sw=2
