#!/usr/bin/env bash
set -euo pipefail

# Render script for YouTube short slides
# - Exposes ffmpeg/ffprobe errors for CI logs
# - Uses absolute paths for concat
# - Falls back if fonts not present on runner

OUT_DIR="out"
mkdir -p "$OUT_DIR"
mkdir -p "captions" "metadata" "assets"

# Fonts (Ubuntu runner usually has these)
FONT_REG="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# Watermark
WATERMARK_DEFAULT="@begumhomedecor"
WATERMARK="${WATERMARK:-$WATERMARK_DEFAULT}"
# Escape single quotes for ffmpeg drawtext
WATERMARK_ESC="${WATERMARK//\'/\'}"

# Timeline (seconds)
HOOK_D=3.0
TIP_D=4.8
CTA_D=3.0
FPS=30

# Colors (hex or names)
BG1="#F3F1ED"  # warm-neutral
BG2="#ECE6DF"  # slightly warmer
FG="#111111"   # text color (near-black)
ACC="#CBB59B"  # accent bar

fade_in="fade=t=in:st=0:d=0.35"

# Helpers
err() { echo "ERROR: $*" >&2; }

# Ensure ffmpeg/ffprobe are available
if ! command -v ffmpeg >/dev/null 2>&1; then
  err "ffmpeg not found in PATH. Please install ffmpeg."
  exit 1
fi
if ! command -v ffprobe >/dev/null 2>&1; then
  err "ffprobe not found in PATH. Please install ffmpeg/ffprobe."
  exit 1
fi

# Font fallbacks
if [[ ! -f "${FONT_BOLD}" ]]; then
  echo "Warning: bold font not found at ${FONT_BOLD}, letting ffmpeg pick default."
  FONT_BOLD=""
fi
if [[ ! -f "${FONT_REG}" ]]; then
  echo "Warning: regular font not found at ${FONT_REG}, letting ffmpeg pick default."
  FONT_REG=""
fi

if [[ -n "${FONT_BOLD}" ]]; then
  draw_watermark="drawtext=fontfile=${FONT_BOLD}:text='${WATERMARK_ESC}':fontsize=36:fontcolor=black@0.55:bordercolor=white@0.7:borderw=2:x=w-tw-36:y=36"
else
  draw_watermark="drawtext=text='${WATERMARK_ESC}':fontsize=36:fontcolor=black@0.55:bordercolor=white@0.7:borderw=2:x=w-tw-36:y=36"
fi

make_slide () {
  local text1="$1"
  local text2="$2"
  local duration="$3"
  local bg="$4"
  local outfile="$5"

  # Escape single quotes for ffmpeg drawtext
  text1="${text1//\'/\'}"
  text2="${text2//\'/\'}"

  local f1=""
  local f2=""
  if [[ -n "${FONT_BOLD}" ]]; then f1="fontfile=${FONT_BOLD}"; fi
  if [[ -n "${FONT_REG}" ]]; then f2="fontfile=${FONT_REG}"; fi

  local line1
  if [[ -n "$f1" ]]; then
    line1="drawtext="">$f1:text='${text1}':fontsize=72:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-120):borderw=2:bordercolor=white@0.8"
  else
    line1="drawtext=text='${text1}':fontsize=72:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-120):borderw=2:bordercolor=white@0.8"
  fi

  local line2=""
  if [[ -n "$text2" ]]; then
    if [[ -n "$f2" ]]; then
      line2=",drawtext=${f2}:text='${text2}':fontsize=54:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-28):borderw=2:bordercolor=white@0.8"
    else
      line2=",drawtext=text='${text2}':fontsize=54:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-28):borderw=2:bordercolor=white@0.8"
    fi
  fi

  local bar="drawbox=x=(w/2-140):y=(h/2+30):w=280:h=8:color=${ACC}:t=fill"
  local st
  st=$(awk -v d="$duration" 'BEGIN {printf "%.2f", d-0.35}')
  local fade_out="fade=t=out:st=${st}:d=0.35"

  echo "Generating slide: ${outfile} (duration=${duration}, bg=${bg})"
  ffmpeg -y -f lavfi -i "color=c=${bg}:s=1080x1920:d=${duration}:r=${FPS}" \
    -vf "${line1}${line2},${bar},${draw_watermark},${fade_in},${fade_out}" \
    -c:v libx264 -pix_fmt yuv420p -r ${FPS} "${outfile}"
}

# Main

echo "Generating slides..."
make_slide "5 Tiny Decor Upgrades" "Under \$20" "${HOOK_D}" "${BG1}" "${OUT_DIR}/s1.mp4"
make_slide "Swap pillow covers" "Texture = luxe" "${TIP_D}" "${BG2}" "${OUT_DIR}/s2.mp4"
make_slide "Warm LED strips" "Ambient glow" "${TIP_D}" "${BG1}" "${OUT_DIR}/s3.mp4"
make_slide "Coffee table: Rule of 3" "Book + Candle + Vase" "${TIP_D}" "${BG2}" "${OUT_DIR}/s4.mp4"
make_slide "Matching frames" "Cohesive walls" "${TIP_D}" "${BG1}" "${OUT_DIR}/s5.mp4"
make_slide "Greenery in a matte vase" "Finishes the look" "${TIP_D}" "${BG2}" "${OUT_DIR}/s6.mp4"
make_slide "Follow for quick home glow-ups!" "" "${CTA_D}" "${BG1}" "${OUT_DIR}/s7.mp4"

# Concat list: absolute paths
cat > "${OUT_DIR}/inputs.txt" <<EOF
file '${PWD}/${OUT_DIR}/s1.mp4'
file '${PWD}/${OUT_DIR}/s2.mp4'
file '${PWD}/${OUT_DIR}/s3.mp4'
file '${PWD}/${OUT_DIR}/s4.mp4'
file '${PWD}/${OUT_DIR}/s5.mp4'
file '${PWD}/${OUT_DIR}/s6.mp4'
file '${PWD}/${OUT_DIR}/s7.mp4'
EOF

ffmpeg -y -f concat -safe 0 -i "${OUT_DIR}/inputs.txt" -c copy "${OUT_DIR}/home-decor-short-temp.mp4"

# Optional music
if [[ -f "assets/music.mp3" ]]; then
  echo "Mixing in background music..."
  DURATION=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "${OUT_DIR}/home-decor-short-temp.mp4" || echo "0")
  if [[ -z "${DURATION}" || "${DURATION}" == "0" ]]; then
    err "Could not determine video duration, skipping music mixing."
  else
    ffmpeg -y -stream_loop -1 -i assets/music.mp3 -t "${DURATION}" -i "${OUT_DIR}/home-decor-short-temp.mp4" \
      -filter_complex "[0:a]volume=0.20,lowpass=f=1400,highpass=f=60[a0];[1:a][a0]amix=inputs=2:duration=shortest:dropout_transition=2,volume=1.0[aout]" \
      -map 1:v:0 -map "[aout]" -c:v copy -c:a aac -b:a 160k "${OUT_DIR}/home-decor-short.mp4"
  fi
else
  ffmpeg -y -i "${OUT_DIR}/home-decor-short-temp.mp4" -f lavfi -t 0.1 -i anullsrc=r=48000:cl=stereo -shortest \
    -c:v copy -c:a aac -b:a 128k "${OUT_DIR}/home-decor-short.mp4"
fi

# Thumbnail near the end (use duration to compute safe timestamp)
VIDEO_DUR=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "${OUT_DIR}/home-decor-short.mp4" || echo "0")
THUMB_TIME="00:00:00"
if [[ -n "${VIDEO_DUR}" && "${VIDEO_DUR}" != "0" ]]; then
  # choose 2s before end or 1s if shorter
  safe=$(awk -v d="${VIDEO_DUR}" 'BEGIN{t=d-2; if(t<0.5) t=0; printf "%d", t}')
  printf -v THUMB_TIME "00:00:%02d" "$safe"
fi
ffmpeg -y -ss "${THUMB_TIME}" -i "${OUT_DIR}/home-decor-short.mp4" -frames:v 1 "${OUT_DIR}/thumbnail.jpg"

echo "Done. Outputs in ${OUT_DIR}/"