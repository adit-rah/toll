#!/bin/bash
# Renders demo scenarios on an iOS simulator (docs/renders.md): for each scenario and variant, a
# screenshot, the accessibility tree, the app's log and any crash report, plus a README.md index.
# Needs macOS with Xcode 26+, python3 and AXe (`brew install cameroncooke/axe/axe`).
#
#   ios/scripts/render.sh [out-dir]          default out-dir: build/renders
#   SCENARIOS  one per line: `<scenario>` or `<scenario>: <axe step>; <axe step>…`
#              (default: every scenario in ALL below). `motion <scenario>: <steps>` also films the
#              steps into motion.mp4, and `wait <seconds>` is a step there (docs/renders.md, "Motion").
#   VARIANTS   any of light dark ax5 dark-ax5 xxxl wordless dark-wordless, space-separated (default: light).
#              xxxl is the largest size below the accessibility sizes.
#              wordless draws every line of text as a placeholder bar (docs/design.md §5).
#   UDID       the simulator to use (default: render-device.sh picks and boots one)
#   XCODEBUILD_ARGS  extra xcodebuild arguments (CI passes its package cache)
#   BUILD_ONLY=1     build and stop
#   SETTLE     most seconds to wait for a screen to stop changing (default 12)
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${1:-$ROOT/build/renders}
DERIVED=$ROOT/build/render-derived
BUNDLE=com.advan.toll
ALL="welcome fit setup-sleep-found setup-sleep-weekends setup-sleep-ask setup-sleep-none setup-around setup-around-before setup-around-off screen-time screen-time-allowed screen-time-denied blocklist ready set-home set-home-off set-home-location set-home-always set-home-location-off set-home-set home-evening home-blocked home-away home-first-week home-last-night home-week home-paused home-location home-screen-time-off home-recovered home-read-only home-no-blocks home-morning home-morning-gap home-morning-away home-morning-card home-day home-strip-night home-strip-day home-pill-purchase home-pause-open home-anywhere home-card home-heads-up home-gap-week home-gap-offer purchase purchase-pending purchase-failed purchase-restore-none purchase-done settings settings-anywhere settings-heads-up-denied settings-while-using insights sleep-monday sleep-best sleep-sky-5 sleep-sky-7 sleep-sky-30 sleep-sky-100 home-morning-landmark sky-share blocks blocks-day block-new block-new-gym block-edit block-edit-on block-night door-choosing door-waiting door-open door-none home-before-bed home-before-bed-card before-bed before-bed-list before-bed-breathe before-bed-words settings-sleep sleep-sky-0 sleep-sky-180 sleep-sky-star sleep-sky-evening sleep-sky-night sleep-sky-morning sleep-sky-names ready-health home-fit-card fit-sheet fit-sheet-sleep fit-sheet-around settings-sleep-after home-morning-open home-morning-landmark-open home-morning-location home-morning-gap-week home-morning-flow home-morning-card-open home-night-hour home-night-hour-monday fit-sheet-around-fitted settings-how-it-works sleep-health-improving sleep-health-flat sleep-health-noisy sleep-dusk sleep-few home-morning-asleep home-morning-asleep-open home-morning-ask-open door-open-used home-pause-waiting home-held-home home-blocked-anywhere sleep-after-trial settings-screen-time-off settings-log welcome-running welcome-used welcome-bought blocks-many blocks-many-day block-place block-delete home-heads-up-on home-heads-up-denied blocks-off block-edit-off"
SCENARIOS=${SCENARIOS:-$(printf '%s\n' $ALL)}
VARIANTS=${VARIANTS:-light}
SETTLE=${SETTLE:-12}
TIMINGS=$OUT/timings.txt
rm -rf "$OUT" && mkdir -p "$OUT" "$DERIVED"
# Whatever stops the run, the published folder says so; fetch-renders.sh would otherwise wait in vain.
trap 'failed_line=$LINENO' ERR
finish() {
  local status=$?
  [ -n "${LOG_PID:-}" ] && kill "$LOG_PID" 2>/dev/null
  if [ "$status" -ne 0 ] && [ ! -f "$OUT/README.md" ]; then
    printf '# Renders\n\nrender.sh stopped at line %s (exit %s). See the workflow log.\n' "${failed_line:-?}" "$status" \
      >"$OUT/README.md"
  fi
}
trap finish EXIT

UDID=${UDID:-$("$ROOT/ios/scripts/render-device.sh")}

# Debug, one simulator architecture, no index store (only the editor reads it). The build folder is kept,
# so on a Mac the next run builds incrementally.
echo "Building for ${UDID}..." >&2
started=$SECONDS
# shellcheck disable=SC2086
if ! xcodebuild build -project "$ROOT/ios/Toll.xcodeproj" -scheme Toll -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" -skipPackagePluginValidation -skipMacroValidation \
  ${XCODEBUILD_ARGS:-} CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO >"$DERIVED.log" 2>&1; then
  { echo "# Renders"; echo; echo "The build failed. Errors:"; echo; echo '```'
    errors=$(grep -E "error: " "$DERIVED.log" | sort -u | head -100 || true)
    if [ -n "$errors" ]; then echo "$errors"; else tail -60 "$DERIVED.log"; fi
    echo '```'; } >"$OUT/README.md"
  cat "$OUT/README.md" >&2
  exit 1
fi
echo "build: $((SECONDS - started)) s" >"$TIMINGS"
APP=$DERIVED/Build/Products/Debug-iphonesimulator/Toll.app
[ -d "$APP" ] || { echo "no $APP" >&2; exit 1; }
if [ "${BUILD_ONLY:-0}" = 1 ]; then cat "$TIMINGS" >&2; exit 0; fi

# Ad hoc, like Xcode signs for the simulator. No entitlements: the simulator refuses restricted ones in a
# signature, so the App Group falls back to a temporary folder and demo launches keep Keychain values in
# memory (Keychain.inMemory). Family Controls has no simulator support at all; demo launches fake it.
for inner in "$APP"/Frameworks/* "$APP"/PlugIns/*.appex; do
  if [ -e "$inner" ]; then codesign --force --sign - "$inner"; fi
done
codesign --force --sign - "$APP"

started=$SECONDS
xcrun simctl bootstatus "$UDID" -b >/dev/null
echo "waiting for the simulator to boot: $((SECONDS - started)) s" >>"$TIMINGS"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3

# One log stream for the whole run, cut per capture by line number: a `log show` per screen cost seconds.
APPLOG=$OUT/.app.log
xcrun simctl spawn "$UDID" log stream --style compact --level debug \
  --predicate 'subsystem BEGINSWITH "com.advan.toll"' >"$APPLOG" 2>/dev/null &
LOG_PID=$!
lines() { wc -l <"$APPLOG" | tr -d ' '; }

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
now() { python3 -c 'import time; print(f"{time.time():.3f}")'; }
since() { python3 -c "import time; print(f'{time.time() - $1:.2f}')"; }
# Films a motion line's steps (docs/renders.md, "Motion"): recording starts before the first step
# and stops 1.5 s after the last, with SIGINT so the file is finalised. The steps run back to back,
# without settling. motion.txt says when each started, in seconds from the recording's start.
film() {
  local dir=$1 steps=$2 step recorder began
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$dir/motion.mp4" >"$dir/record.txt" 2>&1 &
  recorder=$!
  for _ in $(seq 50); do
    if grep -q "Recording started" "$dir/record.txt" 2>/dev/null; then break; fi
    sleep 0.1
  done
  began=$(now)
  # A tap in the recording's first moments was sometimes lost.
  sleep 1
  IFS=';' read -r -a parts <<<"$steps"
  for step in "${parts[@]}"; do
    step=$(trim "$step")
    [ -z "$step" ] && continue
    printf '%s %s\n' "$(since "$began")" "$step" >>"$dir/motion.txt"
    case $step in
      wait\ *) sleep "${step#wait }" ;;
      *) eval "axe $step --udid \"$UDID\"" >>"$dir/steps.txt" 2>&1 || echo "step failed: $step" >>"$dir/steps.txt" ;;
    esac
  done
  sleep 1.5
  kill -INT "$recorder" 2>/dev/null || true
  wait "$recorder" 2>/dev/null || true
}

capture() {
  local variant=$1 line=$2 spec scenario steps dir step marker began=$SECONDS first drawn motion=""
  spec=$line
  case $line in "motion "*) motion=1 spec=${line#motion } ;; esac
  scenario=$(trim "${spec%%:*}")
  steps=""
  case $spec in *:*) steps=${spec#*:} ;; esac
  dir=$OUT/$variant/$(slug "$line")
  mkdir -p "$dir"
  marker=$dir/.started
  touch "$marker"
  # A fresh install per capture, so no scenario sees another's data.
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  first=$(($(lines) + 1))
  # One scenario that will not open is a finding, not a reason to lose the others.
  if ! { xcrun simctl install "$UDID" "$APP" &&
    xcrun simctl launch "$UDID" "$BUNDLE" -TollDemo "$scenario" -TollWordless "$wordless"; } \
    >"$dir/launch.txt" 2>&1; then
    echo "$variant/$(slug "$line"): did not launch" >&2
  fi
  drawn=$(settle)
  if [ -n "$motion" ]; then
    film "$dir" "$steps"
  elif [ -n "$steps" ]; then
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
  sed -n "${first},\$p" "$APPLOG" >"$dir/log.txt"
  find "$HOME/Library/Logs/DiagnosticReports" -name 'Toll*' -newer "$marker" -exec cp {} "$dir/" \; 2>/dev/null || true
  rm "$marker"
  echo "$variant/$(slug "$line"): $((SECONDS - began)) s, first frame after ${drawn} s" | tee -a "$TIMINGS" >&2
}

for variant in $VARIANTS; do
  case $variant in *dark*) appearance=dark ;; *) appearance=light ;; esac
  case $variant in
    *ax5*) size=accessibility-extra-extra-extra-large ;;
    *xxxl*) size=extra-extra-extra-large ;;
    *) size=large ;;
  esac
  case $variant in *wordless*) wordless=YES ;; *) wordless=NO ;; esac
  xcrun simctl ui "$UDID" appearance "$appearance"
  xcrun simctl ui "$UDID" content_size "$size"
  while IFS= read -r line; do
    if [ -n "$(trim "$line")" ]; then capture "$variant" "$line"; fi
  done <<<"$SCENARIOS"
done
rm -f "$APPLOG"

{
  echo "# Renders"
  echo
  echo "Commit \`$(git -C "$ROOT" rev-parse --short HEAD)\` · $(date -u '+%Y-%m-%d %H:%M UTC') ·" \
    "$(xcodebuild -version | sed -n 1p) · $(xcrun simctl list devices -j | python3 -c "
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
    for v in $VARIANTS; do
      printf ' ![](%s/%s/screen.png)' "$v" "$(slug "$line")"
      if [ -f "$OUT/$v/$(slug "$line")/motion.mp4" ]; then printf ' [motion](%s/%s/motion.mp4)' "$v" "$(slug "$line")"; fi
      printf ' |'
    done
    echo
  done <<<"$SCENARIOS"
} >"$OUT/README.md"
echo "Wrote $OUT/README.md" >&2
