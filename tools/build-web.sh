#!/usr/bin/env bash
# Assembles the web version in dist/web: the page, the release SWF and a pinned,
# self-hosted Ruffle (Flash emulator), plus a pinned PixiJS for /pixi/, so the pages depend on no CDN.
# Run tools/build-flash.sh client release first.
set -eu

ruffle_version="0.7.1"
ruffle_sha256="ef12edbee135d581a9cd523837d746da30a07a64dbf1cf472d2e472c656f4b5e"
# PixiJS for the JS build (/pixi/): the version Kadokadeo uses with the pixi-haxe externs.
pixi_version="6.0.2"
pixi_sha256="2d44efaa49be95ff02c36b911a492d8699ea2bee5f095619feb624908cef37ab"

cd "$(dirname "$0")/.."
swf="client/client/bin/flash/bin/rockFallerMobile.swf"
[ -f "$swf" ] || { echo "missing $swf: run tools/build-flash.sh client release" >&2; exit 1; }

site="dist/web"
rm -rf "$site"
mkdir -p "$site/ruffle"
cp web/index.html web/language.mjs web/favicon.ico "$site/"
mkdir -p "$site/img" "$site/font"
cp www/img/bg_game.jpg www/img/ogFb.png "$site/img/"
cp -R web/img/flags "$site/img/"
cp assets/BenchNine-Regular.ttf "$site/font/"
cp -R client/client/sfx "$site/sfx"  # the game's sounds, for the JS build
cp "$swf" "$site/rockfaller.swf"

archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
curl -sSLf -o "$archive" \
  "https://github.com/ruffle-rs/ruffle/releases/download/v$ruffle_version/ruffle-$ruffle_version-web-selfhosted.zip"
echo "$ruffle_sha256  $archive" | shasum -a 256 -c - >/dev/null
unzip -q "$archive" -d "$site/ruffle"
rm -f "$site"/ruffle/*.map

mkdir -p "$site/pixi"
curl -sSLf -o "$archive" "https://registry.npmjs.org/pixi.js/-/pixi.js-$pixi_version.tgz"
echo "$pixi_sha256  $archive" | shasum -a 256 -c - >/dev/null
tar xzf "$archive" -O package/dist/browser/pixi.min.js > "$site/pixi/pixi.min.js"
# The game's assets, under the ids the game asks for (see html5/src/AssetManifest.hx).
mkdir -p "$site/pixi/assets/data" "$site/pixi/assets/assets"
cp -R client/client/assetsWeb/. "$site/pixi/assets/"
cp data/loot.json "$site/pixi/assets/data/"
cp client/client/assets/BenchNine-Regular.ttf client/client/assets/Mouse_Deco.ttf "$site/pixi/assets/assets/"
cp html5/game.html "$site/pixi/"
cp html5/index.html client/client/assetsWeb/assets1.png client/client/assetsWeb/assets1.xml client/client/assetsWeb/taupinotron.png client/client/assetsWeb/taupinotron.xml "$site/pixi/"

echo "web version in $site"
