#!/bin/bash
# Prints the UDID of the simulator renders use and starts it booting in the background. A first boot
# takes minutes, so the workflow calls this before anything else and render.sh waits for it.
# The device is the newest plain "iPhone N" on the newest iOS runtime; one is created if none exists.
set -euo pipefail
read -r UDID RUNTIME TYPE < <(xcrun simctl list -j devices available runtimes | python3 -c '
import json, re, sys
data = json.load(sys.stdin)
runtimes = [r for r in data["runtimes"] if r["platform"] == "iOS" and r.get("isAvailable", True)]
runtime = max(runtimes, key=lambda r: [int(p) for p in r["version"].split(".")])
number = lambda name: int(name.split()[1])
devices = [d for d in data["devices"].get(runtime["identifier"], []) if re.fullmatch(r"iPhone \d+", d["name"])]
phones = [t for t in runtime["supportedDeviceTypes"] if re.fullmatch(r"iPhone \d+", t["name"])]
best = max(devices, key=lambda d: number(d["name"]))["udid"] if devices else "-"
print(best, runtime["identifier"], max(phones, key=lambda t: number(t["name"]))["identifier"])')
if [ "$UDID" = - ]; then UDID=$(xcrun simctl create toll-render "$TYPE" "$RUNTIME"); fi
nohup xcrun simctl boot "$UDID" >/dev/null 2>&1 &
echo "$UDID"
