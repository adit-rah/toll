#!/bin/bash
# Renders demo scenarios on an iOS simulator (docs/renders.md): for each scenario and variant, a
# screenshot, the accessibility tree, the app's log and any crash report, plus a README.md index.
# Needs macOS with Xcode 26+, python3 and AXe (`brew install cameroncooke/axe/axe`).
#
#   ios/scripts/render.sh [out-dir]          default out-dir: build/renders
#   SCENARIOS  one per line: `<scenario>` or `<scenario>: <axe step>; <axe step>…`
#              (default: every scenario in DemoLaunch.swift)
#   VARIANTS   any of light dark ax5 dark-ax5, space-separated (default: light)
#   API TOKEN  from render-api.sh; without them the signed-in scenarios land on Welcome
#   XCODEBUILD_ARGS  extra xcodebuild arguments (CI passes its package cache)
#   BUILD_ONLY=1     build and stop (CI uses it on main to fill the build cache feature branches start from)
#   SETTLE     most seconds to wait for a screen to stop changing (default 12)
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${1:-$ROOT/build/renders}
DERIVED=$ROOT/build/render-derived
BUNDLE=com.advan.toll
ALL="welcome permissions setup-blocks solo-home home insights people gate screen-time-off"
SCENARIOS=${SCENARIOS:-$(printf '%s\n' $ALL)}
VARIANTS=${VARIANTS:-light}
SETTLE=${SETTLE:-12}
TIMINGS=$OUT/timings.txt
rm -rf "$OUT" && mkdir -p "$OUT" "$DERIVED"
# Whatever stops the run, the published folder says so; fetch-renders.sh would otherwise wait in vain.
trap 'failed_line=$LINENO' ERR
finish() {
  local status=$?
  if [ "$status" -ne 0 ] && [ ! -f "$OUT/README.md" ]; then
    printf '# Renders\n\nrender.sh stopped at line %s (exit %s). See the workflow log.\n' "${failed_line:-?}" "$status" \
      >"$OUT/README.md"
  fi
}
trap finish EXIT

UDID=${UDID:-$("$ROOT/ios/scripts/render-device.sh")}

# Xcode 26's compilation cache is keyed by content, not timestamps, so a cache restored from another
# run is reused only where the inputs are byte-for-byte the same; the result matches a clean build.
build() {
  # shellcheck disable=SC2086
  xcodebuild build -project "$ROOT/ios/Toll.xcodeproj" -scheme Toll -configuration Debug \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" -skipPackagePluginValidation -skipMacroValidation \
    ${XCODEBUILD_ARGS:-} CODE_SIGNING_ALLOWED=NO COMPILATION_CACHE_ENABLE_CACHING=YES \
    COMPILER_INDEX_STORE_ENABLE=NO >"$DERIVED.log" 2>&1
}
source_errors() { grep -E "/ios/(App|ShieldConfig|ShieldAction|Monitor|Packages)/.*error: " "$DERIVED.log" || true; }
echo "Building for ${UDID}..." >&2
cached=no
[ -d "$DERIVED/Build" ] && cached=yes
started=$SECONDS
built=yes
if ! build; then
  # An error in our own code is the answer. Anything else after a restored cache could be the cache,
  # so it gets one clean build before it counts.
  if [ "$cached" = yes ] && [ -z "$(source_errors)" ]; then
    echo "Cached build failed outside the sources; building clean." >&2
    rm -rf "$DERIVED" && mkdir -p "$DERIVED"
    cached="no (cache discarded)"
    build || built=no
  else
    built=no
  fi
fi
echo "build: $((SECONDS - started)) s, cache restored: $cached" >"$TIMINGS"
if [ "$built" = no ]; then
  { echo "# Renders"; echo; echo "The build failed. Errors:"; echo; echo '```'
    errors=$(grep -E "error: " "$DERIVED.log" | sort -u | head -100 || true)
    if [ -n "$errors" ]; then echo "$errors"; else tail -60 "$DERIVED.log"; fi
    echo '```'; } >"$OUT/README.md"
  cat "$OUT/README.md" >&2
  exit 1
fi
APP=$DERIVED/Build/Products/Debug-iphonesimulator/Toll.app
[ -d "$APP" ] || { echo "no $APP" >&2; exit 1; }
if [ "${BUILD_ONLY:-0}" = 1 ]; then cat "$TIMINGS" >&2; exit 0; fi

# Ad hoc, like Xcode signs for the simulator. No entitlements: the simulator refuses restricted ones in a
# signature, so the App Group falls back to a temporary folder and demo launches keep the session in
# memory (Keychain.inMemory). Family Controls has no simulator support at all; DemoLaunch fakes it.
for inner in "$APP"/Frameworks/* "$APP"/PlugIns/*.appex; do
  if [ -e "$inner" ]; then codesign --force --sign - "$inner"; fi
done
codesign --force --sign - "$APP"

started=$SECONDS
xcrun simctl bootstatus "$UDID" -b >/dev/null
echo "waiting for the simulator to boot: $((SECONDS - started)) s" >>"$TIMINGS"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}
# Waits until the accessibility tree has content and reads the same twice in a row: the screen has drawn
# and the local Worker has answered. While the app is still launching the tree is an empty shell, which
# is not a screen. Prints the seconds until the first tree with content.
settle() {
  local previous="" current deadline=$((SECONDS + SETTLE)) began=$SECONDS drawn=""
  while [ "$SECONDS" -lt "$deadline" ]; do
    sleep 0.7
    current=$(axe describe-ui --udid "$UDID" 2>/dev/null || true)
    if printf '%s' "$current" | python3 -c '
import json, sys
def labelled(n):
    return bool(n.get("AXLabel")) and n.get("type") != "Application" or any(labelled(c) for c in n.get("children") or [])
try: sys.exit(0 if any(labelled(n) for n in json.load(sys.stdin)) else 1)
except Exception: sys.exit(1)'; then
      [ -z "$drawn" ] && drawn=$((SECONDS - began))
      if [ "$current" = "$previous" ]; then break; fi
      previous=$current
    fi
  done
  echo "${drawn:-never}"
}
slug() { printf '%s' "$1" | tr -cs 'A-Za-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-60; }
capture() {
  local variant=$1 line=$2 scenario steps dir step marker began=$SECONDS
  scenario=$(trim "${line%%:*}")
  steps=""
  case $line in *:*) steps=${line#*:} ;; esac
  dir=$OUT/$variant/$(slug "$line")
  mkdir -p "$dir"
  marker=$dir/.started
  touch "$marker"
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  local since
  since=$(date '+%Y-%m-%d %H:%M:%S')
  # One scenario that will not open is a finding, not a reason to lose the others.
  if ! { xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" "$BUNDLE" -TollDemo "$scenario" \
    ${TOKEN:+-TollDemoToken "$TOKEN"} ${API:+-TollDemoAPI "$API"}; } >"$dir/launch.txt" 2>&1; then
    echo "$variant/$(slug "$line"): did not launch" >&2
  fi
  local drawn
  drawn=$(settle)
  if [ -n "$steps" ]; then
    IFS=';' read -r -a parts <<<"$steps"
    for step in "${parts[@]}"; do
      step=$(trim "$step")
      [ -z "$step" ] && continue
      eval "axe $step --udid \"$UDID\"" >>"$dir/steps.txt" 2>&1 || echo "step failed: $step" >>"$dir/steps.txt"
      settle >/dev/null
    done
  fi
  xcrun simctl io "$UDID" screenshot "$dir/screen.png" >/dev/null 2>&1
  sips --resampleWidth 600 "$dir/screen.png" >/dev/null
  axe describe-ui --udid "$UDID" >"$dir/ui.json" 2>&1 || true
  xcrun simctl spawn "$UDID" log show --style compact --info --debug --start "$since" \
    --predicate 'subsystem BEGINSWITH "com.advan.toll"' >"$dir/log.txt" 2>&1 || true
  find "$HOME/Library/Logs/DiagnosticReports" -name 'Toll*' -newer "$marker" -exec cp {} "$dir/" \; 2>/dev/null || true
  rm "$marker"
  echo "$variant/$(slug "$line"): $((SECONDS - began)) s, first frame after ${drawn} s" | tee -a "$TIMINGS" >&2
}

for variant in $VARIANTS; do
  case $variant in *dark*) appearance=dark ;; *) appearance=light ;; esac
  case $variant in *ax5*) size=accessibility-extra-extra-extra-large ;; *) size=large ;; esac
  xcrun simctl ui "$UDID" appearance "$appearance"
  xcrun simctl ui "$UDID" content_size "$size"
  while IFS= read -r line; do
    if [ -n "$(trim "$line")" ]; then capture "$variant" "$line"; fi
  done <<<"$SCENARIOS"
done

{
  echo "# Renders"
  echo
  echo "Commit \`$(git -C "$ROOT" rev-parse --short HEAD)\` · $(date -u '+%Y-%m-%d %H:%M UTC') ·" \
    "$(xcodebuild -version | head -1) · $(xcrun simctl list devices -j | python3 -c "
import json, sys
for runtime, ds in json.load(sys.stdin)['devices'].items():
  for d in ds:
    if d['udid'] == '$UDID': print(d['deviceTypeIdentifier'].split('.')[-1], runtime.split('.')[-1])")"
  echo
  echo "Each folder holds screen.png, ui.json (accessibility tree), log.txt (app log), launch.txt, and any"
  echo "crash report. Where the time went: timings.txt."
  echo
  printf '| Scenario |'
  for v in $VARIANTS; do printf ' %s |' "$v"; done
  printf '\n|---|'
  for _ in $VARIANTS; do printf -- '---|'; done
  echo
  while IFS= read -r line; do
    [ -z "$(trim "$line")" ] && continue
    printf '| `%s` |' "$line"
    for v in $VARIANTS; do printf ' ![](%s/%s/screen.png) |' "$v" "$(slug "$line")"; done
    echo
  done <<<"$SCENARIOS"
} >"$OUT/README.md"
echo "Wrote $OUT/README.md" >&2
