#!/usr/bin/env bash
# Assembles the web version in dist/web: the page, the release SWF and a pinned,
# self-hosted Ruffle (Flash emulator), so the page depends on no CDN.
# Run tools/build-flash.sh client release first.
set -eu

ruffle_version="0.7.1"
ruffle_sha256="ef12edbee135d581a9cd523837d746da30a07a64dbf1cf472d2e472c656f4b5e"

cd "$(dirname "$0")/.."
swf="client/client/bin/flash/bin/rockFallerMobile.swf"
[ -f "$swf" ] || { echo "missing $swf: run tools/build-flash.sh client release" >&2; exit 1; }

site="dist/web"
rm -rf "$site"
mkdir -p "$site/ruffle"
cp web/index.html "$site/index.html"
cp "$swf" "$site/rockfaller.swf"

archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
curl -sSLf -o "$archive" \
  "https://github.com/ruffle-rs/ruffle/releases/download/v$ruffle_version/ruffle-$ruffle_version-web-selfhosted.zip"
echo "$ruffle_sha256  $archive" | shasum -a 256 -c - >/dev/null
unzip -q "$archive" -d "$site/ruffle"
rm -f "$site"/ruffle/*.map

echo "web version in $site"
