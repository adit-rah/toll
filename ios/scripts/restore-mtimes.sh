#!/bin/bash
# Sets each tracked file under ios/ to the time of the last commit that touched it. A fresh checkout
# stamps every file "now", which makes a restored build cache think everything changed.
set -euo pipefail
cd "$(dirname "$0")/../.."
git log --format='@%ct' --name-only --no-renames HEAD -- ios | python3 -c '
import os, sys
seen, stamp = set(), None
for line in sys.stdin:
    line = line.rstrip("\n")
    if line.startswith("@"):
        stamp = int(line[1:])
    elif line and line not in seen:
        seen.add(line)
        if os.path.exists(line):
            os.utime(line, (stamp, stamp))
print(f"restored {len(seen)} timestamps", file=sys.stderr)'
