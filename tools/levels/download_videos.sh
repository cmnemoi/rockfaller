#!/usr/bin/env bash
# Downloads the Rockfaller Journey playthrough (20 videos, levels 1 to 180) in 720p, without audio.
set -eu
cd "$(dirname "$0")/../.."
yt-dlp --no-warnings -f 136 -o ".cache/videos/%(playlist_index)02d-%(id)s.%(ext)s" \
  "https://www.youtube.com/playlist?list=PLVHaVMlXRNl7CztZj_biaFGHSgDMpAZfT"
