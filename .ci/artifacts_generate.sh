#!/usr/bin/env bash

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${CI_DIR}/common.sh"

[[ $# -eq 2 ]] || die "2 arguments expected, got $#"
platform="$1"
macosx_deployment_target="$2"
shift 2

version="$(git describe --match='v[0-9]*')"
run sh -c "echo '${version}' >version.txt"

artifacts=()
case "${platform}" in
    android-*)
        artifacts+=("koreader-${platform}-${version}.apk")
        ;;
    linux-*)
        case "${platform}" in
            linux-aarch64) deb_arch='arm64' ;;
            linux-armhf) deb_arch='armhf' ;;
            linux-x86_64) deb_arch='amd64' ;;
            *) die "unsupported platform: ${platform}" ;;
        esac
        artifacts+=(
            "koreader-${version}-${platform#linux-}.AppImage"
            "koreader-${platform}-${version}.tar.xz"
            "koreader_${version#v}-1_${deb_arch}.deb"
        )
        fi
        ;;
    cervantes | kindle* | kobo* | pocketbook* | remarkable*)
        artifacts+=("koreader-${platform}-${version}.zip")
        ;;
    macos-arm64 | macos-x86_64)
        artifacts+=("koreader-macos-${macosx_deployment_target}-${platform#macos-}-${version}.7z")
        ;;
    *) die "unsupported platform: ${platform}" ;;
esac

for a in "${artifacts[@]}"; do
    case "${a}" in
        *.7z) run 7z a "${a}" version.txt ;;
        *.apk) run cp fake.apk "${a}" ;;
        *.AppImage) run cp /usr/bin/true "${a}" ;;
        *.deb) run ar q "${a}" version.txt ;;
        *.targz) run tar czf "${a}" version.txt ;;
        *.tar.xz)
            a="${a%.xz}"
            run tar cf "${a}" --record-size=512 version.txt
            if [[ -n "${DRY_RUN}" ]]; then
                size=2048
            else
                size="$(stat -c %s "${a}")"
            fi
            run xz -9 --block-list=$((size - 512 * 2)),0 "${a}"
            ;;
        *.zip) run zip "${a}" version.txt ;;
    esac
done
