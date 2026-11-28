#!/bin/bash
# Prints the UDID of the simulator renders use and starts it booting in the background. A first boot
# takes minutes, so the workflow calls this before anything else and render.sh waits for it.
# The device is a booted plain "iPhone N" on the newest iOS runtime if there is one, else the newest such
# iPhone; one is created if none exists. RENDER_DEVICE names another device type instead, such as
# "iPhone SE (3rd generation)" for the smallest screen; an unknown name falls back to the newest iPhone.
set -euo pipefail
read -r UDID RUNTIME TYPE STATE < <(xcrun simctl list -j devices available runtimes | python3 -c '
import json, os, re, sys
data = json.load(sys.stdin)
runtimes = [r for r in data["runtimes"] if r["platform"] == "iOS" and r.get("isAvailable", True)]
runtime = max(runtimes, key=lambda r: [int(p) for p in r["version"].split(".")])
want = os.environ.get("RENDER_DEVICE", "")
if not any(t["name"] == want for t in runtime["supportedDeviceTypes"]):
    if want: print(f"No device type {want!r}; using the newest iPhone", file=sys.stderr)
    want = ""
picked = (lambda name: name == want) if want else (lambda name: re.fullmatch(r"iPhone \d+", name))
number = (lambda name: 0) if want else (lambda name: int(name.split()[1]))
devices = [d for d in data["devices"].get(runtime["identifier"], []) if picked(d["name"])]
phones = [t for t in runtime["supportedDeviceTypes"] if picked(t["name"])]
booted = [d for d in devices if d.get("state") == "Booted"]
best = max(booted or devices, key=lambda d: number(d["name"])) if devices else {"udid": "-", "state": "-"}
print(best["udid"], runtime["identifier"], max(phones, key=lambda t: number(t["name"]))["identifier"], best.get("state", "-"))')
if [ "$UDID" = - ]; then UDID=$(xcrun simctl create toll-render "$TYPE" "$RUNTIME"); fi
# On a Mac the simulator is usually up already; only a cold one needs the boot and the warm-up.
if [ "$STATE" = Booted ]; then echo "$UDID"; exit 0; fi
# The first app launch after a boot took two minutes on a runner. Opening Settings once, in the
# background, pays that while the build runs instead of during the first screenshot.
nohup bash -c 'xcrun simctl boot "$1" 2>/dev/null; xcrun simctl bootstatus "$1" -b &&
  xcrun simctl launch "$1" com.apple.Preferences && sleep 15 &&
  xcrun simctl terminate "$1" com.apple.Preferences' _ "$UDID" >/dev/null 2>&1 &
echo "$UDID"
