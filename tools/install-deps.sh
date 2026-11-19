#!/usr/bin/env bash
# Installs the pinned haxelibs into the project-local repo ($HAXELIB_PATH, set by mise.toml).
set -eu

: "${HAXELIB_PATH:?run through mise so HAXELIB_PATH points to the project repo}"
mkdir -p "$HAXELIB_PATH"

for lib in openfl:3.6.1 lime:2.9.1 hxsl:2.0.6 castle:1.6.1 format:3.2.1; do
  haxelib install "${lib%%:*}" "${lib##*:}" --always
done
haxelib set format 3.2.1 --always # castle pulls a newer format that breaks hxsl
haxelib git h3d https://github.com/delahee/h3d.git 59f92055b84c4e6058dadcd6032b21258f29a2fd --always
