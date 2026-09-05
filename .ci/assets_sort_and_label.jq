include "assets_parse";

[$ARGS.positional[] | asset_parse]
# Sort by version (decreasing, tie-break on platform & extension).
| sort_by([(.base_version | split(".") | map(tonumber | -.)), .commit_number, .platform, .extension])
# Label.
| .[] | .file + "#" + ([.version, .platform_name, "(" + .extension + ")"] | join(" "))

# vim: sw=2
