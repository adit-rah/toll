#!/bin/sh
# Xcode Cloud runs this after cloning (Apple's ci_scripts convention). A build started by a `vX.Y.Z`
# tag ships as version X.Y.Z, with Xcode Cloud's own run number as the build, so TestFlight always
# matches the release that made it (ledger A133). Other builds keep Base.xcconfig's values.
set -eu

if [ -z "${CI_TAG:-}" ]; then
  echo "Not a tag build; keeping Base.xcconfig's version."
  exit 0
fi

version=$(printf '%s' "$CI_TAG" | sed -n 's/^v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$/\1/p')
if [ -z "$version" ]; then
  echo "error: tag '$CI_TAG' is not vX.Y.Z; refusing to upload a build with the wrong version." >&2
  exit 1
fi

config="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}/ios/Config/Version.xcconfig"
{
  echo "MARKETING_VERSION = $version"
  echo "CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER:?Xcode Cloud sets CI_BUILD_NUMBER}"
} >"$config"
echo "Version $version ($CI_BUILD_NUMBER) from tag $CI_TAG"
