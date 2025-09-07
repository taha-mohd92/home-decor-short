# Home Decor YouTube Short (Auto-render)

This repo renders a ready-to-upload 1080x1920 MP4 YouTube Short with on-screen text and a clean, neutral aesthetic. Music is optional (add via YouTube editor or add your own MP3 in `assets/`).

What it generates
- out/home-decor-short.mp4 — 30s Short (vertical, H.264 + AAC)
- out/thumbnail.jpg — a still frame near the end for upload
- captions/short-home-decor-captions.srt — optional captions to upload
- metadata/ (title, description, hashtags)

Defaults (customizable later)
- Theme: Living room, minimal-cozy
- VO: Captions-only (no voiceover)
- Music: None included by default (you can add one)
- Watermark: @taha_home

Quick start
- GitHub Actions: Actions → “Render YouTube Short” → Run workflow. Download the artifacts.
- Local: Ensure ffmpeg is installed, then run:
  bash scripts/render.sh

Customize
- Change watermark: set env var WATERMARK (e.g., WATERMARK="@your_handle" bash scripts/render.sh) or edit the script default.
- Edit text: Update the strings in scripts/render.sh for each slide.
- Add music: Put an MP3 at assets/music.mp3 and re-run. The script mixes it at a safe level.

License notes
- The rendered video uses only programmatic graphics and your text. If you add stock images/video/music, ensure they are license-safe.