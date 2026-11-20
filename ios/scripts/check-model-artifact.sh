#!/bin/bash
# Checks a model artifact's schema version and checksum with nothing but sed and a SHA-256 tool, so a
# build machine needs no Python (model spec, section 2). The checksum covers the file with its own
# sha256 value written as "".
#   ios/scripts/check-model-artifact.sh [artifact.json ...]
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
schema=1
[ $# -gt 0 ] || set -- "$root/ios/Packages/SleepModel/Sources/SleepModel/Resources/sleep-model.v0.json"
if command -v sha256sum >/dev/null; then sha=(sha256sum); else sha=(shasum -a 256); fi
status=0
for file in "$@"; do
  if ! grep -Eq "^  \"schema\": $schema,\$" "$file"; then
    echo "$file: schema is not $schema" >&2
    status=1
    continue
  fi
  stated=$(sed -nE 's/^  "sha256": "([0-9a-f]{64})"$/\1/p' "$file")
  actual=$(sed -E 's/^  "sha256": "[0-9a-f]{64}"$/  "sha256": ""/' "$file" | "${sha[@]}" | cut -d' ' -f1)
  if [ -z "$stated" ] || [ "$stated" != "$actual" ]; then
    echo "$file: checksum does not match (stated ${stated:-none}, actual $actual)" >&2
    status=1
  else
    echo "$file: schema $schema, checksum ok"
  fi
done
exit $status
