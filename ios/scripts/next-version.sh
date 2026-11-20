#!/bin/sh
# Prints the next release version (X.Y.Z, no "v"), worked out from the repository's tags, so nobody
# picks a number by hand (docs/releasing.md). The patch counts up from the newest vX.Y.Z tag;
# `ios/Config/Base.xcconfig`'s MARKETING_VERSION sets the major and minor, so a minor release is a
# reviewed edit there (0.2.x -> 0.3.0). Fails if Base.xcconfig is behind the tags.
#
#   ios/scripts/next-version.sh            the next version
#   ios/scripts/next-version.sh --check    exit 1 if Base.xcconfig is behind the newest tag
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
config="$root/ios/Config/Base.xcconfig"

planned=$(sed -n 's/^MARKETING_VERSION = \([0-9][0-9]*\.[0-9][0-9]*\)\.[0-9][0-9]*$/\1/p' "$config")
if [ -z "$planned" ]; then
  echo "error: no MARKETING_VERSION = X.Y.Z in $config" >&2
  exit 1
fi

latest=$(git -C "$root" tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
latest_minor=${latest%.*}

# Which of the two major.minor pairs is higher, by sorting them as versions.
higher=$(printf '%s\n%s\n' "$planned" "${latest_minor:-0.0}" | sort -t. -k1,1n -k2,2n | tail -1)

if [ -n "$latest" ] && [ "$higher" != "$planned" ]; then
  echo "error: Base.xcconfig says $planned.x but the newest tag is v$latest; raise MARKETING_VERSION to $latest_minor.0." >&2
  exit 1
fi

if [ "${1:-}" = "--check" ]; then
  echo "ok: Base.xcconfig $planned.x, newest tag ${latest:+v$latest}"
  exit 0
fi

if [ -n "$latest" ] && [ "$latest_minor" = "$planned" ]; then
  echo "$latest_minor.$(( ${latest##*.} + 1 ))"
else
  echo "$planned.0"
fi
