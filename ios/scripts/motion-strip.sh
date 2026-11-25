#!/bin/bash
# Turns a render's motion.mp4 into something an agent can read (docs/renders.md, "Motion"): the
# frames at 60 fps around the interaction, a filmstrip of every 2nd frame for SPAN ms after it with
# timestamps, and each frame's change from the one before, to spot pops, dead frames and double
# animations. Needs ffmpeg, ffprobe and python3 with Pillow; runs on Linux or macOS.
#
#   ios/scripts/motion-strip.sh <motion.mp4> [out-dir]   default out-dir: <video's folder>/strip
#   AT     seconds into the video where the interaction starts (default: the first frame that
#          changes after the first step in motion.txt beside the video)
#   SPAN   milliseconds the strip covers from AT (default 600)
#   CROP   w:h:x:y in the video's pixels, to look closer at one part (default: the whole screen)
#   TILE   width in pixels of each frame in the strip (default 220)
#
# Writes frames/NNNN.png, strip.png (the frames, then a bar per frame of its change) and change.txt
# (per frame: ms from AT, mean absolute difference from the frame before, and a flag).
set -euo pipefail
VIDEO=${1:?usage: motion-strip.sh <motion.mp4> [out-dir]}
OUT=${2:-$(dirname "$VIDEO")/strip}
SPAN=${SPAN:-600}
TILE=${TILE:-220}
CROP=${CROP:-}
rm -rf "$OUT" && mkdir -p "$OUT/frames" "$OUT/scan"

# The first step's time, if the runner logged one; the video starts with the recording.
first_step=0
log=$(dirname "$VIDEO")/motion.txt
if [ -f "$log" ]; then first_step=$(awk 'NR == 1 { print $1 }' "$log"); fi

crop=${CROP:+crop=$CROP,}
# A small pass over the whole video finds the interaction: the first frame after the first step
# that differs from the one before it.
if [ -z "${AT:-}" ]; then
  ffmpeg -v error -i "$VIDEO" -vf "${crop}fps=60,scale=160:-2" "$OUT/scan/%05d.png"
  AT=$(python3 - "$OUT/scan" "$first_step" <<'PY'
import os, sys
from PIL import Image, ImageChops, ImageStat
folder, after = sys.argv[1], float(sys.argv[2])
names = sorted(os.listdir(folder))
previous = None
for index, name in enumerate(names):
    frame = Image.open(os.path.join(folder, name)).convert("L")
    t = index / 60
    if previous is not None and t >= after:
        if ImageStat.Stat(ImageChops.difference(frame, previous)).mean[0] > 0.05:
            print(f"{max(0, t - 1 / 60):.3f}")
            break
    previous = frame
else:
    print(f"{after:.3f}")
PY
  )
fi
rm -rf "$OUT/scan"

# From 100 ms before AT to 400 ms after the strip ends, at 60 fps whatever the video's own rate:
# the simulator writes a frame only when the screen changes, so a repeated frame is a dead one.
start=$(python3 -c "print(max(0, $AT - 0.1))")
length=$(python3 -c "print($SPAN / 1000 + 0.5)")
ffmpeg -v error -ss "$start" -i "$VIDEO" -t "$length" -vf "${crop}fps=60" "$OUT/frames/%04d.png"

python3 - "$OUT" "$AT" "$start" "$SPAN" "$TILE" <<'PY'
import os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat
out, at, start, span, tile = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
names = sorted(os.listdir(os.path.join(out, "frames")))
frames = [Image.open(os.path.join(out, "frames", n)).convert("RGB") for n in names]
ms = [round((start + i / 60 - at) * 1000) for i in range(len(frames))]
change = [0.0] + [
    ImageStat.Stat(ImageChops.difference(a.convert("L"), b.convert("L"))).mean[0]
    for a, b in zip(frames[1:], frames)
]

# Flags. A pop: one frame carries most of a motion, far more than the frames on either side. A dead
# frame: nothing changes between two frames that do, mid-motion. A restart: the screen goes still
# for 50 ms or more and then moves again, inside the strip (two animations where one was meant).
still = 0.05
flags = [""] * len(frames)
for i in range(1, len(frames) - 1):
    around = [change[j] for j in range(max(1, i - 3), min(len(frames), i + 4)) if j != i]
    if change[i] > 1 and change[i] > 4 * max(around + [0.01]):
        flags[i] = "pop"
    elif change[i] <= still and change[i - 1] > still and change[i + 1] > still:
        flags[i] = "dead"
moving = [c > still for c in change]
run, seen_motion = 0, False
for i, m in enumerate(moving):
    if m:
        if seen_motion and run >= 3 and 0 <= ms[i] <= span:
            flags[i] = flags[i] or "restart"
        seen_motion, run = True, 0
    else:
        run += 1

with open(os.path.join(out, "change.txt"), "w") as f:
    f.write(f"# AT {at:.3f} s into the video; ms from AT, mean absolute difference (0-255), flag\n")
    for t, c, flag in zip(ms, change, flags):
        f.write(f"{t:5d} {c:8.3f} {flag}\n")

# The strip: every 2nd frame from AT for SPAN ms, six to a row, each with its time.
picked = [i for i, t in enumerate(ms) if 0 <= t <= span][::2]
w, h = frames[0].size
th = round(h * tile / w)
columns = min(6, len(picked))
rows = (len(picked) + columns - 1) // columns
label, chart, pad = 22, 120, 8
sheet = Image.new("RGB", (columns * (tile + pad) + pad, rows * (th + label + pad) + pad + chart + 30), "white")
draw = ImageDraw.Draw(sheet)
try:
    draw.font = ImageFont.load_default(size=15)
except TypeError:
    pass
for k, i in enumerate(picked):
    x, y = pad + (k % columns) * (tile + pad), pad + (k // columns) * (th + label + pad)
    sheet.paste(frames[i].resize((tile, th)), (x, y + label))
    draw.text((x, y + 4), f"+{ms[i]} ms {flags[i]}".strip(), fill="red" if flags[i] else "black")

# Under it, one bar per frame of the whole window: its change from the frame before.
top = rows * (th + label + pad) + pad + 20
left, width = pad, sheet.width - 2 * pad
peak = max(change + [1])
bar = width / len(frames)
draw.text((left, top - 16), f"change per frame (peak {peak:.2f}); red: flagged; line: AT", fill="black")
for i, c in enumerate(change):
    height = c / peak * chart
    x = left + i * bar
    draw.rectangle([x, top + chart - height, x + max(1, bar - 1), top + chart], fill="red" if flags[i] else "gray")
zero = left + ms.index(min(ms, key=abs)) * bar
draw.line([zero, top, zero, top + chart], fill="blue")
sheet.save(os.path.join(out, "strip.png"))
print(f"{len(frames)} frames from {start:.2f} s; AT {at:.3f} s; {sum(1 for f in flags if f)} flagged")
for t, c, flag in zip(ms, change, flags):
    if flag:
        print(f"  {flag} at {t} ms ({c:.2f})")
PY
echo "$OUT/strip.png, $OUT/change.txt"
