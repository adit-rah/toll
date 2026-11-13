#!/bin/bash
# Fetches the renders the render workflow pushed for a branch into a folder, waiting until they are of
# the commit asked for (docs/renders.md). Needs only git: no Mac, no GitHub API.
#
#   ios/scripts/fetch-renders.sh [out-dir]   default out-dir: build/renders
#   BRANCH  the branch that was rendered (default: the current one)
#   COMMIT  the commit to wait for (default: HEAD); WAIT=0 takes whatever is there
#   TIMEOUT seconds to wait (default 2400)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${1:-$ROOT/build/renders}
BRANCH=${BRANCH:-$(git -C "$ROOT" branch --show-current)}
COMMIT=$(git -C "$ROOT" rev-parse --short=7 "${COMMIT:-HEAD}")
deadline=$(($(date +%s) + ${TIMEOUT:-2400}))

while :; do
  if git -C "$ROOT" fetch -q --depth 1 origin "refs/heads/renders/$BRANCH" 2>/dev/null; then
    subject=$(git -C "$ROOT" log -1 --format=%s FETCH_HEAD)
    case $subject in *"$COMMIT"*) break ;; esac
    [ "${WAIT:-1}" = 0 ] && break
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "No renders of $COMMIT on renders/$BRANCH yet. Is the run going? It starts on a push whose" \
      "message says [render], or on a workflow_dispatch of render.yml." >&2
    exit 1
  fi
  sleep 30
done

rm -rf "$OUT" && mkdir -p "$OUT"
git -C "$ROOT" archive FETCH_HEAD | tar -x -C "$OUT"
echo "$(git -C "$ROOT" log -1 --format=%s FETCH_HEAD) → $OUT" >&2
cat "$OUT/README.md"
