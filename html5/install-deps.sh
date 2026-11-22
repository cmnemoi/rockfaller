#!/usr/bin/env bash
# Installs the pinned haxelibs of the JS build into html5/.haxelib ($HAXELIB_PATH, set by html5/mise.toml).
set -eu

: "${HAXELIB_PATH:?run through mise in html5/ so HAXELIB_PATH points to html5/.haxelib}"
mkdir -p "$HAXELIB_PATH"

haxelib install perf.js 1.1.8 --always # pixijs's only dependency, pinned before it pulls the latest

# Kadokadeo's fork of the PixiJS externs (blend modes, cursor), used with PixiJS 6.0.2.
haxelib git pixijs https://gitlab.com/eternaltwin/kadokadeo/pixi-haxe.git 57a718ce5239c62d99fb788529c51770eecf2106 --always
