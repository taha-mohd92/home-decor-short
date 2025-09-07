#!/usr/bin/env bash
set -euo pipefail

# Config
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
WATERMARK_ESC="${WATERMARK//\'/\\'}"

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
# fade out starts 0.35s before end; computed per slide

draw_watermark="drawtext=fontfile=${FONT_BOLD}:text='${WATERMARK_ESC}':fontsize=36:fontcolor=black@0.55:bordercolor=white@0.7:borderw=2:x=w-tw-36:y=36"

make_slide () {
  local text1="$1"
  local text2="$2"
  local duration="$3"
  local bg="$4"
  local outfile="$5"

  # Escape single quotes for ffmpeg drawtext
  text1="${text1//\'/\\'}"
  text2="${text2//\'/\\'}"

  # Build drawtext filters for lines (centered)
  local line1="drawtext=fontfile=${FONT_BOLD}:text='${text1}':fontsize=72:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-120):borderw=2:bordercolor=white@0.8"
  local line2=""
  if [[ -n "$text2" ]]; then
    line2=",drawtext=fontfile=${FONT_REG}:text='${text2}':fontsize=54:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-28):borderw=2:bordercolor=white@0.8"
  fi

  # Accent bar under title
  local bar="drawbox=x=(w/2-140):y=(h/2+30):w=280:h=8:color=${ACC}:t=fill"

  # Fade out timing (avoid nested quoting issues)
  local st
  st=$(awk -v d="$duration" 'BEGIN {printf "%.2f", d-0.35}')
  local fade_out="fade=t=out:st=${st}:d=0.35"

  ffmpeg -y -f lavfi -i "color=c=${bg}:s=1080x1920:d=${duration}:r=${FPS}" \
    -vf "${line1}${line2},${bar},${draw_watermark},${fade_in},${fade_out}" \
    -c:v libx264 -pix_fmt yuv420p -r ${FPS} "${outfile}" >/dev/null 2>&1
}

echo "Generating slides..."

# Slide 1: Hook
make_slide "5 Tiny Decor Upgrades" "Under \$20" "${HOOK_D}" "${BG1}" "${OUT_DIR}/s1.mp4"

# Slide 2: Tip 1
make_slide "Swap pillow covers" "Texture = luxe" "${TIP_D}" "${BG2}" "${OUT_DIR}/s2.mp4"

# Slide 3: Tip 2
make_slide "Warm LED strips" "Ambient glow" "${TIP_D}" "${BG1}" "${OUT_DIR}/s3.mp4"

# Slide 4: Tip 3
make_slide "Coffee table: Rule of 3" "Book + Candle + Vase" "${TIP_D}" "${BG2}" "${OUT_DIR}/s4.mp4"

# Slide 5: Tip 4
make_slide "Matching frames" "Cohesive walls" "${TIP_D}" "${BG1}" "${OUT_DIR}/s5.mp4"

# Slide 6: Tip 5
make_slide "Greenery in a matte vase" "Finishes the look" "${TIP_D}" "${BG2}" "${OUT_DIR}/s6.mp4"

# Slide 7: CTA
make_slide "Follow for quick home glow-ups!" "" "${CTA_D}" "${BG1}" "${OUT_DIR}/s7.mp4"

# Concat list
cat > "${OUT_DIR}/inputs.txt" <<EOF
file 's1.mp4'
file 's2.mp4'
file 's3.mp4'
file 's4.mp4'
file 's5.mp4'
file 's6.mp4'
file 's7.mp4'
EOF

# Concatenate
ffmpeg -y -f concat -safe 0 -i "${OUT_DIR}/inputs.txt" -c copy "${OUT_DIR}/home-decor-short-temp.mp4" >/dev/null 2>&1

# Optional music: if assets/music.mp3 exists, mix it
if [[ -f "assets/music.mp3" ]]; then
  echo "Mixing in background music..."
  # - Shorten/loop music to match video length, duck volume
  DURATION=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nw=1:nk=1 "${OUT_DIR}/home-decor-short-temp.mp4")
  ffmpeg -y -stream_loop -1 -i assets/music.mp3 -t "${DURATION}" -i "${OUT_DIR}/home-decor-short-temp.mp4" \
    -filter_complex "[0:a]volume=0.20,lowpass=f=1400,highpass=f=60[a0];[1:a][a0]amix=inputs=2:duration=shortest:dropout_transition=2,volume=1.0[aout]" \
    -map 1:v:0 -map "[aout]" -c:v copy -c:a aac -b:a 160k "${OUT_DIR}/home-decor-short.mp4" >/dev/null 2>&1
else
  # No music; just ensure we have an AAC track (silent) for broader compatibility
  ffmpeg -y -i "${OUT_DIR}/home-decor-short-temp.mp4" -f lavfi -t 0.1 -i anullsrc=r=48000:cl=stereo -shortest \
    -c:v copy -c:a aac -b:a 128k "${OUT_DIR}/home-decor-short.mp4" >/dev/null 2>&1
fi

# Thumbnail near the end
ffmpeg -y -ss 00:00:27 -i "${OUT_DIR}/home-decor-short.mp4" -frames:v 1 "${OUT_DIR}/thumbnail.jpg" >/dev/null 2>&1

echo "Done. Outputs in ${OUT_DIR}/"