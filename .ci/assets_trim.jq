include "assets_parse";

[
  $ARGS.positional[] | asset_parse
  # Ignore latest stable / nightly files.
  | select(.ota | not)
]
# Group by stable / nightly…
| [
  [.[] | select(.stable)],
  [.[] | select(.stable | not)]
]
# | debug
# …and each list in turn by decreasing version.
| map(group_by(.sort_version) | reverse)
# | debug
# Trim:
| .[0][$stable_keep_count - 1][0].sort_version // [-1] as $oldest_stable_version #| debug($oldest_stable_version)
| (
  # - keep the last $stable_keep_count stables
  .[0][$stable_keep_count:],
  [.[1][] | select(.[0].sort_version > $oldest_stable_version)][$nightly_keep_count:]
)
| flatten | .[].file

# vim: sw=2
