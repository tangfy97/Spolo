#!/bin/zsh
# End-to-end test of the merge engine with generated media: videos in H.264, HEVC and HLG HDR, portrait
# video stored sideways, variable frame rate, clips with and without sound at different sample rates,
# photos with EXIF rotation, and an MKV that must be skipped. Each merge is checked frame by frame:
# every clip's colour, its white top-left block (so it is upright), black bars, length and sound.
#
#   scripts/test-merge.sh
#
# Needs ffmpeg (brew install ffmpeg) to make the test videos and read the results.
set -euo pipefail
cd "$(dirname "$0")/.."

media=build/test-media
out=build/test-output
mkdir -p $media $out
swift build -q --product spolo
spolo=.build/debug/spolo

# Colour with a white block in the top-left corner, as the clip should be seen.
card() { echo "color=c=${1}:s=${2}:r=${3}:d=${4},drawbox=x=0:y=0:w=iw*0.2:h=ih*0.2:color=white:t=fill"; }
tone() { echo "sine=frequency=${1}:sample_rate=${2}:duration=${3}"; }
ff() { ffmpeg -hide_banner -loglevel error -y "$@"; }

if [[ ! -f $media/h_clip.mkv ]]; then
  echo "==> Making test media"
  ff -f lavfi -i "$(card red 1920x1080 30 4)" -f lavfi -i "$(tone 440 48000 4)" -ac 2 \
     -c:v libx264 -pix_fmt yuv420p -g 30 -c:a aac -b:a 128k $media/a_land.mp4
  ff -f lavfi -i "$(card 0x800000 1920x1080 30 3)" -f lavfi -i "$(tone 440 48000 3)" -ac 2 \
     -c:v libx264 -pix_fmt yuv420p -g 30 -c:a aac -b:a 128k $media/a2_land.mp4
  # A phone's portrait video: stored 1920×1080 and turned for display by the track transform. No sound.
  ff -f lavfi -i "$(card green 1080x1920 30 3)" -vf transpose=2 -c:v libx265 -tag:v hvc1 -pix_fmt yuv420p \
     -x265-params log-level=error $media/b_stored.mov
  ff -display_rotation -90 -i $media/b_stored.mov -c copy $media/b_portrait.mov
  rm $media/b_stored.mov
  # HLG HDR in 10-bit HEVC, 25 fps, sound at 44.1 kHz.
  ff -f lavfi -i "$(card blue 1920x1080 25 3)" -f lavfi -i "$(tone 660 44100 3)" -ac 2 \
     -vf "scale=out_color_matrix=bt2020:out_range=tv,format=yuv420p10le" \
     -c:v libx265 -tag:v hvc1 -x265-params "log-level=error:colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc" \
     -color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc -c:a aac $media/c_hlg.mov
  # Variable frame rate (dropped and uneven frames, like a screen recording), mono sound at 22.05 kHz.
  ff -f lavfi -i "$(card yellow 1280x720 30 3)" -f lavfi -i "$(tone 330 22050 3)" \
     -vf "select='not(eq(mod(n\,7)\,0))',setpts='(N+0.4*mod(N\,3))/30/TB'" -fps_mode vfr \
     -c:v libx264 -pix_fmt yuv420p -c:a aac -ac 1 $media/d_vfr.mp4
  swift scripts/test-photos.swift $media
  ff -f lavfi -i "$(card white 640x360 30 1)" -c:v libvpx-vp9 $media/h_clip.mkv
fi

echo "==> Probing"
$spolo probe $media/*

# check <file> <frame width> <frame height> <fill|fit> <expected sound> then clips as colour:width:height:seconds
check() {
  /usr/bin/python3 - "$@" <<'EOF'
import json, subprocess, sys
path, W, H, mode, sound = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
clips = [(c, int(w), int(h), float(s)) for c, w, h, s in (a.split(":") for a in sys.argv[6:])]
failures = []
def expect(ok, what):
    print(("  ✓ " if ok else "  ✗ ") + what)
    if not ok: failures.append(what)

probe = json.loads(subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", path],
                                  capture_output=True, text=True, check=True).stdout)
video = [s for s in probe["streams"] if s["codec_type"] == "video"][0]
audio = [s for s in probe["streams"] if s["codec_type"] == "audio"]
total = sum(c[3] for c in clips)
length = float(probe["format"]["duration"])
expect((video["width"], video["height"]) == (W, H), f"frame {video['width']}×{video['height']} (expected {W}×{H})")
expect(abs(length - total) < 0.15, f"length {length:.2f}s (expected {total:.2f}s)")
if sound == "yes":
    expect(len(audio) == 1 and abs(float(audio[0]["duration"]) - total) < 0.2,
           f"one sound track as long as the video ({audio[0]['duration'] if audio else 'none'})")
else:
    expect(not audio, "no sound track")

def frame(t):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.3f}", "-i", path, "-frames:v", "1", "-f", "rawvideo",
                          "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return lambda x, y: raw[(int(y) * W + int(x)) * 3:(int(y) * W + int(x)) * 3 + 3]

def colour(px):
    r, g, b = px
    if max(px) < 40: return "black"
    if min(px) > 200: return "white"
    if r > 200 and 90 < g < 170 and b < 60: return "orange"
    hi = max(px)
    on = tuple(v > hi * 0.6 for v in px)
    return {(1,0,0): "red", (0,1,0): "green", (0,0,1): "blue", (1,1,0): "yellow", (1,0,1): "magenta",
            (0,1,1): "cyan"}.get(on, f"{r},{g},{b}")

start = 0
for name, w, h, seconds in clips:
    at = frame(start + seconds / 2)
    scale = (max if mode == "fill" else min)(W / w, H / h)
    cw, ch = w * scale, h * scale
    x0, y0 = (W - cw) / 2, (H - ch) / 2
    inside = lambda fx, fy: (min(W - 1, max(0, x0 + cw * fx)), min(H - 1, max(0, y0 + ch * fy)))
    centre = colour(at(*inside(0.6, 0.6)))
    expected = "red" if name == "maroon" else name
    expect(centre == expected, f"{name} clip at {start + seconds / 2:.2f}s shows {centre}")
    if mode == "fit":
        expect(colour(at(*inside(0.08, 0.08))) == "white", f"{name} clip is upright (white block top-left)")
        if cw < W - 4: expect(colour(at(2, H / 2)) == "black", f"{name} clip has black bars at the sides")
        if ch < H - 4: expect(colour(at(W / 2, 2)) == "black", f"{name} clip has black bars above and below")
    start += seconds

sys.exit(1 if failures else 0)
EOF
}

# Frequency of the sound between two times, from zero crossings.
pitch() {
  ffmpeg -v error -ss $2 -t $3 -i $1 -ac 1 -ar 48000 -f s16le - | /usr/bin/python3 -c '
import sys, array
a = array.array("h", sys.stdin.buffer.read())
crossings = sum(1 for i in range(1, len(a)) if (a[i-1] < 0) != (a[i] < 0))
print(round(crossings / 2 / (len(a) / 48000)))'
}

failed=0
echo "==> 1. Everything, Auto shape, fit, original quality"
$spolo merge -o $out/mixed.mp4 $media/a_land.mp4 $media/b_portrait.mov $media/c_hlg.mov $media/d_vfr.mp4 \
  $media/e_photo.jpg $media/f_photo_turned.heic $media/g_photo.png $media/h_clip.mkv
check $out/mixed.mp4 1920 1080 fit yes red:1920:1080:4 green:1080:1920:3 blue:1920:1080:3 \
  yellow:1280:720:2.57 magenta:4032:3024:3 cyan:1200:1600:3 orange:800:1200:3 || failed=1

echo "==> 2. 9:16, fill, high quality, MOV, with edits"
$spolo merge -o $out/edited.mov --shape 9:16 --fill --quality high "$media/a_land.mp4@speed=2,trim=0.5:0.5" \
  "$media/b_portrait.mov@turn=1" "$media/d_vfr.mp4@mute,speed=0.5" "$media/e_photo.jpg@dur=1.5" "$media/g_photo.png@turn=2,dur=1"
check $out/edited.mov 1080 1920 fill yes red:1920:1080:1.5 green:1920:1080:3 yellow:1280:720:5.14 magenta:4032:3024:1.5 orange:800:1200:1 || failed=1
hz=$(pitch $out/edited.mov 0.2 1)
[[ $hz -gt 400 && $hz -lt 480 ]] && echo "  ✓ 2× clip keeps its pitch (${hz} Hz, source 440 Hz)" || { echo "  ✗ 2× clip pitch ${hz} Hz"; failed=1; }

echo "==> 3. Photos only, 1:1"
$spolo merge -o $out/photos.mp4 --shape 1:1 $media/e_photo.jpg $media/f_photo_turned.heic $media/g_photo.png
check $out/photos.mp4 1920 1920 fit no magenta:4032:3024:3 cyan:1200:1600:3 orange:800:1200:3 || failed=1

echo "==> 4. Matching clips are joined without re-encoding"
log=$($spolo merge -o $out/joined.mp4 $media/a_land.mp4 "$media/a2_land.mp4@trim=0:1")
echo $log | tail -1
[[ $log == *"without re-encoding"* ]] && echo "  ✓ joined without re-encoding" || { echo "  ✗ re-encoded"; failed=1; }
check $out/joined.mp4 1920 1080 fit yes red:1920:1080:4 maroon:1920:1080:2 || failed=1

echo
if [[ $failed == 0 ]]; then print -P "%F{green}All merges correct.%f"; else print -P "%F{red}Some checks failed.%f"; exit 1; fi
