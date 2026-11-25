#!/bin/bash
# Copies the exported model artifact, the parity fixtures and the rebuild fixture from datascience/
# into the SleepModel package (model spec, section 2), and writes the artifact's version into TollCore
# for the extensions, which never link the model (#140). With --check, changes nothing and fails if
# any copy differs, which CI runs so the app never ships numbers the reference didn't produce.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
from="$root/datascience/artifacts"
pkg="$root/ios/Packages/SleepModel"
artifact="$from/sleep-model.v0.json"
pairs=(
  "$artifact:$pkg/Sources/SleepModel/Resources/sleep-model.v0.json"
  "$from/fixtures.jsonl:$pkg/Tests/SleepModelTests/Fixtures/fixtures.jsonl"
  "$from/rebuild.json:$pkg/Tests/SleepModelTests/Fixtures/rebuild.json"
)
status=0
check() {
  if ! cmp -s "$1" "$2"; then
    echo "out of sync: ${2#"$root"/} (run ios/scripts/sync-model.sh)" >&2
    status=1
  fi
}
for pair in "${pairs[@]}"; do
  src="${pair%%:*}" dst="${pair#*:}"
  if [ "${1:-}" = "--check" ]; then check "$src" "$dst"; else cp "$src" "$dst"; fi
done

version=$(sed -nE 's/^  "version": "([^"]+)",?$/\1/p' "$artifact")
[ -n "$version" ] || { echo "no version in ${artifact#"$root"/}" >&2; exit 1; }
generated="$root/ios/Packages/TollCore/Sources/TollCore/Persist/BundledModel.swift"
swift=$(mktemp)
trap 'rm -f "$swift"' EXIT
cat >"$swift" <<EOF
/// The artifact this build carries, for the monitor's night records: the extensions never link the
/// model, and model.json can name an older one until the app opens after an update (#140). Written
/// by ios/scripts/sync-model.sh from the artifact, never by hand.
public enum BundledModel {
  public static let version = "$version"
}
EOF
if [ "${1:-}" = "--check" ]; then check "$swift" "$generated"; else cp "$swift" "$generated"; fi
exit $status
