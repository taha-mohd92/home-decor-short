#!/usr/bin/env bash
set -euo pipefail
set -x

OUT_DIR="out"
mkdir -p "$OUT_DIR"
mkdir -p "captions" "metadata" "assets"

FONT_REG="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

WATERMARK_DEFAULT="@begumhomedecor"
WATERMARK="${WATERMARK:-$WATERMARK_DEFAULT}"
WATERMARK_ESC="${WATERMARK//\'/\\'}"

HOOK_D=3.0
TIP_D=4.8
CTA_D=3.0
FPS=30

BG1="#F3F1ED"
BG2="#ECE6DF"
FG="#111111"
ACC="#CBB59B"

fade_in="fade=t=in:st=0:d=0.35"

err() { echo "ERROR: $*" >&2; }

if ! command -v ffmpeg >/dev/null 2>&1; then
  err "ffmpeg not found in PATH. Please install ffmpeg."
  exit 1
fi
if ! command -v ffprobe >/dev/null 2>&1; then
  err "ffprobe not found in PATH. Please install ffmpeg/ffprobe."
  exit 1
fi

export FFREPORT="file=${OUT_DIR}/ffmpeg-report.log:level=32"
FFLOG="${OUT_DIR}/ffmpeg.log"
: >"$FFLOG"

run_ff() {
  echo "+ ffmpeg $*" >>"$FFLOG"
  ffmpeg -hide_banner -loglevel verbose "$@" >>"$FFLOG" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "ffmpeg exited with $rc (see ${FFLOG})" >&2
    return $rc
  fi
  return 0
}

if [ ! -f "${FONT_BOLD}" ]; then
  echo "Warning: bold font not found at ${FONT_BOLD}, letting ffmpeg pick default." | tee -a "$FFLOG"
  FONT_BOLD=""
fi
if [ ! -f "${FONT_REG}" ]; then
  echo "Warning: regular font not found at ${FONT_REG}, letting ffmpeg pick default." | tee -a "$FFLOG"
  FONT_REG=""
fi

if [ -n "${FONT_BOLD}" ]; then
  draw_watermark="drawtext=fontfile=${FONT_BOLD}:text='${WATERMARK_ESC}':fontsize=36:fontcolor=black@0.55:bordercolor=white@0.7:borderw=2:x=w-tw-36:y=36"
else
  draw_watermark="drawtext=text='${WATERMARK_ESC}':fontsize=36:fontcolor=black@0.55:bordercolor=white@0.7:borderw=2:x=w-tw-36:y=36"
fi

make_slide() {
  text1="$1"
  text2="$2"
  duration="$3"
  bg="$4"
  outfile="$5"

  text1="${text1//\'/\\'}"
  text2="${text2//\'/\\'}"

  f1=""
  f2=""
  if [ -n "${FONT_BOLD}" ]; then f1="fontfile=${FONT_BOLD}"; fi
  if [ -n "${FONT_REG}" ]; then f2="fontfile=${FONT_REG}"; fi

  if [ -n "$f1" ]; then
    line1="drawtext=$f1:text='${text1}':fontsize=72:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-120):borderw=2:bordercolor=white@0.8"
  else
    line1="drawtext=text='${text1}':fontsize=72:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-120):borderw=2:bordercolor=white@0.8"
  fi

  line2=""
  if [ -n "${text2}" ]; then
    if [ -n "$f2" ]; then
      line2=",drawtext=${f2}:text='${text2}':fontsize=54:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-28):borderw=2:bordercolor=white@0.8"
    else
      line2=",drawtext=text='${text2}':fontsize=54:fontcolor=${FG}:x=(w-text_w)/2:y=(h/2-28):borderw=2:bordercolor=white@0.8"
    fi
  fi

  bar="drawbox=x=(w/2-140):y=(h/2+30):w=280:h=8:color=${ACC}:t=fill"
  st=$(awk -v d="$duration" 'BEGIN {printf "%.2f", d-0.35}')
  fade_out="fade=t=out:st=${st}:d=0.35"

  echo "Generating slide: ${outfile} (duration=${duration}, bg=${bg})" >>"$FFLOG"
  run_ff -y -f lavfi -i "color=c=${bg}:s=1080x1920:d=${duration}:r=${FPS}" \
    -vf "${line1}${line2},${bar},${draw_watermark},${fade_in},${fade_out}" \
    -c:v libx264 -pix_fmt yuv420p -r ${FPS} "${outfile}"
}

echo "Generating slides..." >>"$FFLOG"
make_slide "5 Tiny Decor Upgrades" "Under \$20" "${HOOK_D}" "${BG1}" "${OUT_DIR}/s1.mp4"
make_slide "Swap pillow covers" "Texture = luxe" "${TIP_D}" "${BG2}" "${OUT_DIR}/s2.mp4"
make_slide "Warm LED strips" "Ambient glow" "${TIP_D}" "${BG1}" "${OUT_DIR}/s3.mp4"
make_slide "Coffee table: Rule of 3" "Book + Candle + Vase" "${TIP_D}" "${BG2}" "${OUT_DIR}/s4.mp4"
make_slide "Matching frames" "Cohesive walls" "${TIP_D}" "${BG1}" "${OUT_DIR}/s5.mp4"
make_slide "Greenery in a matte vase" "Finishes the look" "${TIP_D}" "${BG2}" "${OUT_DIR}/s6.mp4"
make_slide "Follow for quick home glow-ups!" "" "${CTA_D}" "${BG1}" "${OUT_DIR}/s7.mp4"

cat >"${OUT_DIR}/inputs.txt" <<EOF
file '${PWD}/${OUT_DIR}/s1.mp4'
file '${PWD}/${OUT_DIR}/s2.mp4'
file '${PWD}/${OUT_DIR}/s3.mp4'
file '${PWD}/${OUT_DIR}/s4.mp4'
file '${PWD}/${OUT_DIR}/s5.mp4'
file '${PWD}/${OUT_DIR}/s6.mp4'
file '${PWD}/${OUT_DIR}/s7.mp4'
