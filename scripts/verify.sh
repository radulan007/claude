#!/usr/bin/env bash
# End-to-end check: render with HyperFrames and Remotion, then edit the results
# with FFmpeg (crossfade, audio mix + loudness normalisation, burned-in captions,
# multi-codec export) and assert every output with ffprobe.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/verify-output"
HF_VERSION="0.8.216"
rm -rf "$OUT" && mkdir -p "$OUT"

pass=0; fail=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$*"; pass=$((pass + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fail=$((fail + 1)); }

# expect FILE CODEC WIDTH HEIGHT MIN_DURATION
expect() {
  local f="$1" codec="$2" w="$3" h="$4" dur="$5" got
  if [ ! -s "$f" ]; then bad "$(basename "$f") missing"; return; fi
  got="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height \
    -show_entries format=duration -of default=nw=1:nk=1 "$f" | tr '\n' ' ')"
  read -r c gw gh d <<<"$got"
  if [ "$c" = "$codec" ] && [ "$gw" = "$w" ] && [ "$gh" = "$h" ] && awk "BEGIN{exit !($d >= $dur)}"; then
    ok "$(basename "$f"): $c ${gw}x${gh} ${d}s"
  else
    bad "$(basename "$f"): got '$got', want $codec ${w}x${h} >=${dur}s"
  fi
}

echo "== Tool versions"
echo "  node $(node -v) | npm $(npm -v)"
echo "  $(ffmpeg -version | head -1)"
echo "  hyperframes $(cd "$ROOT/hyperframes" && npx --yes "hyperframes@$HF_VERSION" --version 2>/dev/null | tail -1)"
echo "  remotion $(cd "$ROOT/remotion" && node -p 'require("remotion/package.json").version')"

echo "== FFmpeg capabilities"
enc="$(ffmpeg -hide_banner -encoders 2>/dev/null)"; flt="$(ffmpeg -hide_banner -filters 2>/dev/null)"
for e in libx264 libx265 libvpx-vp9 libsvtav1 prores_ks aac libopus libmp3lame; do
  grep -q " $e " <<<"$enc" && ok "encoder $e" || bad "encoder $e"
done
for f in xfade subtitles drawtext loudnorm zscale lut3d overlay chromakey; do
  grep -q " $f " <<<"$flt" && ok "filter $f" || bad "filter $f"
done

echo "== HyperFrames: check + render"
(cd "$ROOT/hyperframes" && npx --yes "hyperframes@$HF_VERSION" check >"$OUT/hyperframes-check.log" 2>&1) \
  && ok "hyperframes check" || bad "hyperframes check (see $OUT/hyperframes-check.log)"
(cd "$ROOT/hyperframes" && npx --yes "hyperframes@$HF_VERSION" render -o "$OUT/hyperframes.mp4" --quiet \
  >"$OUT/hyperframes-render.log" 2>&1) || bad "hyperframes render (see $OUT/hyperframes-render.log)"
expect "$OUT/hyperframes.mp4" h264 1920 1080 4.9

echo "== Remotion: typecheck + render"
(cd "$ROOT/remotion" && npx tsc --noEmit) && ok "remotion typecheck" || bad "remotion typecheck"
(cd "$ROOT/remotion" && npx remotion render Demo "$OUT/remotion.mp4" >"$OUT/remotion-render.log" 2>&1) \
  || bad "remotion render (see $OUT/remotion-render.log)"
expect "$OUT/remotion.mp4" h264 1920 1080 4.9

echo "== FFmpeg editing pipeline"
cat >"$OUT/captions.srt" <<'SRT'
1
00:00:00,500 --> 00:00:04,000
HyperFrames

2
00:00:04,500 --> 00:00:08,500
Remotion
SRT
# 1. Normalise frame rate/timebase (the renderers differ), crossfade the two renders (1s overlap) and lay a music bed under it, loudness-normalised to -14 LUFS.
ffmpeg -v error -y -i "$OUT/hyperframes.mp4" -i "$OUT/remotion.mp4" \
  -f lavfi -i "sine=frequency=220:duration=9,volume=0.4" \
  -filter_complex "[0:v]fps=30,settb=AVTB,format=yuv420p[v0];[1:v]fps=30,settb=AVTB,format=yuv420p[v1];[v0][v1]xfade=transition=fade:duration=1:offset=4,format=yuv420p[v];[2:a]afade=t=in:d=0.5,afade=t=out:st=8:d=1,loudnorm=I=-14:TP=-1.5:LRA=11[a]" \
  -map "[v]" -map "[a]" -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k -movflags +faststart \
  "$OUT/edit.mp4" && expect "$OUT/edit.mp4" h264 1920 1080 8.9
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$OUT/edit.mp4" | grep -q aac \
  && ok "edit.mp4 has AAC audio" || bad "edit.mp4 audio track"
# 2. Burn in captions and add a text overlay.
ffmpeg -v error -y -i "$OUT/edit.mp4" \
  -vf "subtitles=$OUT/captions.srt:force_style='FontName=Inter,FontSize=28,Outline=2',drawtext=font=Inter:text='DRAFT':x=w-tw-40:y=40:fontsize=36:fontcolor=white@0.6" \
  -c:v libx264 -crf 20 -c:a copy "$OUT/edit-captioned.mp4" && expect "$OUT/edit-captioned.mp4" h264 1920 1080 8.9
# 3. Delivery formats.
ffmpeg -v error -y -i "$OUT/edit.mp4" -c:v libx265 -crf 24 -x265-params log-level=error -tag:v hvc1 -c:a copy "$OUT/edit-hevc.mp4" || true
expect "$OUT/edit-hevc.mp4" hevc 1920 1080 8.9
ffmpeg -v error -y -i "$OUT/edit.mp4" -c:v libvpx-vp9 -crf 32 -b:v 0 -deadline realtime -cpu-used 8 -c:a libopus "$OUT/edit.webm" || true
expect "$OUT/edit.webm" vp9 1920 1080 8.9
ffmpeg -v error -y -i "$OUT/edit.mp4" -c:v prores_ks -profile:v 3 -c:a pcm_s16le "$OUT/edit-prores.mov" || true
expect "$OUT/edit-prores.mov" prores 1920 1080 8.9
ffmpeg -v error -y -i "$OUT/edit.mp4" -vf "crop=ih*9/16:ih,scale=1080:1920" -c:v libx264 -crf 20 -c:a copy "$OUT/edit-vertical.mp4" || true
expect "$OUT/edit-vertical.mp4" h264 1080 1920 8.9
ffmpeg -v error -y -i "$OUT/edit.mp4" -vf "fps=12,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$OUT/edit.gif" || true
expect "$OUT/edit.gif" gif 640 360 8.0
ffmpeg -v error -y -i "$OUT/edit-captioned.mp4" -vf "select='eq(n\,30)+eq(n\,90)+eq(n\,150)+eq(n\,240)',scale=480:-1,tile=4x1" \
  -frames:v 1 "$OUT/contact-sheet.png" && ok "contact-sheet.png" || bad "contact-sheet.png"

echo
echo "== $pass passed, $fail failed. Outputs in $OUT"
[ "$fail" -eq 0 ]
