#!/bin/bash
# Copies the exported model artifact, the parity fixtures and the rebuild fixture from datascience/
# into the SleepModel package (model spec, section 2). With --check, changes nothing and fails if the
# copies differ, which CI runs so the app never ships numbers the reference didn't produce.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
from="$root/datascience/artifacts"
pkg="$root/ios/Packages/SleepModel"
pairs=(
  "$from/sleep-model.v0.json:$pkg/Sources/SleepModel/Resources/sleep-model.v0.json"
  "$from/fixtures.jsonl:$pkg/Tests/SleepModelTests/Fixtures/fixtures.jsonl"
  "$from/rebuild.json:$pkg/Tests/SleepModelTests/Fixtures/rebuild.json"
)
status=0
for pair in "${pairs[@]}"; do
  src="${pair%%:*}" dst="${pair#*:}"
  if [ "${1:-}" = "--check" ]; then
    if ! cmp -s "$src" "$dst"; then
      echo "out of sync: ${dst#"$root"/} (run ios/scripts/sync-model.sh)" >&2
      status=1
    fi
  else
    cp "$src" "$dst"
  fi
done
exit $status
