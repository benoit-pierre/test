{
  # Android:
  "android-arm": "Android ARM",
  "android-arm64": "Android ARM64",
  # Kindle:
  "kindle": "Kindle",
  "kindle-legacy": "Kindle Legacy",
  "kindlehf": "Kindle HF",
  "kindlepw2": "Kindle PW2",
  # Linux:
  "linux-x86_64": "Linux x86_64",
} as $platform_name |
"-(?<platform>.+)" as $platform_rx |
"-(?<version>v(?<base_version>[0-9]+(\\.[0-9]+)*)(-(?<commit_number>[0-9]+)-g(?<commit_hash>[a-f0-9]+))?)" as $version_rx |
"(?<extension>(\\.[^.]+)+)$" as $extension_rx |
[ 
  $ARGS.positional[] | . as $file | $file | (
    # koreader-linux-x86_64-v2023.06.1.tar.xz
    # koreader-ubuntu-touch-arm-v2015.11-640-g17e9a8e_2018-03-09.targz
    # koreader-android-arm-v2015.11-654-gb7392f7_2018-03-09.apk
    capture("/koreader" + $platform_rx + $version_rx + $extension_rx)
    # koreader-v2023.06.1-x86_64.AppImage
    # koreader-v2025.10-197-g7c5ee9c1a2_2026-03-13-x86_64.AppImage
    // (
         capture("/koreader" + $version_rx + $platform_rx + $extension_rx)
         | .platform = "linux-" + .platform
    )
    # koreader-kindlepw2-latest-nightly.kotasync
    # koreader-kindlepw2-latest-stable.zsync
    // (
      capture("/koreader" + $platform_rx + "-latest" + "-(?<version>[^.]+)" + $extension_rx)
      | .base_version = "-666"
    )
    // error("unsupported asset: " + .)
  ) # | debug |
  # Finalize.
  | .commit_number = (.commit_number // "0" | tonumber)
  | .file = $file
  | .extension = .extension[1:]
  | .platform_name = ($platform_name[.platform] // error("invalid platform: " + .platform))
  # | debug
]
# Sort by version (decreasing, tie-break on platform & extension).
| sort_by([(.base_version | split(".") | map(tonumber | -.)), .commit_number, .platform, .extension])
# Label.
| .[] | .file + "#" + ([.platform_name, .version, "(" + .extension + ")"] | join(" "))

# vim: sw=2
