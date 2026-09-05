include "assets_parse";

[
  $ARGS.positional[] | asset_parse
  # Ignore latest stable / nightly files.
  | select(.latest_ota | not)
]
# Group by stable / nightly…
| group_by(.commit_number and true or false) 
# …and each list in turn by decreasing version.
| map(group_by(.sort_version) | reverse)
# Trim everything but the $stable_keep_count last stables and last $nightly_keep_count nightlies.
| (.[0][$stable_keep_count:], .[1][$nightly_keep_count:]) | flatten | .[].file

# vim: sw=2
