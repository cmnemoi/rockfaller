#!/usr/bin/env bash
set -eu

project="${1:-client}"
mode="${2:-release}"

case "$project" in
  client) dir="client/client"; asset_dir="assetsWeb"; output="rockFallerMobile.swf" ;;
  editor|levelEditor) dir="client/levelEditor"; asset_dir="../client/assetsWeb"; output="levelEditor.swf" ;;
  *) echo "usage: $0 [client|editor] [debug|release]" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/../$dir" || exit 1
while IFS= read -r image; do
  image="${image#imagePath=\"}"
  image="${image%\"}"
  [ -f "$asset_dir/$image" ] || { echo "missing asset: $asset_dir/$image" >&2; exit 1; }
done < <(grep -h -o 'imagePath="[^"]*"' "$asset_dir"/*.xml || true)
if ! haxelib list | grep -q '^format:.*3.2.1'; then
  haxelib install format 3.2.1
fi

# The archived h3d fork and hxsl 2.0.6 disagree on three tiny Flash APIs.
hxsl_dir="$(haxelib path hxsl | awk '/^\// { print; exit }')"
h3d_dir="$(haxelib path h3d | awk '/^\// && /h3d/ { print; exit }')"
patch_dir="$(mktemp -d)"
restore() {
  [ -f "$patch_dir/hxsl-Shader.hx" ] && cp "$patch_dir/hxsl-Shader.hx" "$hxsl_dir/hxsl/Shader.hx"
  [ -f "$patch_dir/Stage3dDriver.hx" ] && cp "$patch_dir/Stage3dDriver.hx" "$h3d_dir/h3d/impl/Stage3dDriver.hx"
  [ -f "$patch_dir/DrawProfiler.hx" ] && cp "$patch_dir/DrawProfiler.hx" "$h3d_dir/hxd/DrawProfiler.hx"
  rm -rf "$patch_dir"
}
trap restore EXIT INT TERM

python3 - "$hxsl_dir" "$h3d_dir" "$patch_dir" <<'PY'
from pathlib import Path
import shutil
import sys

hxsl, h3d, backup = map(Path, sys.argv[1:])

def patch(path, old, new, backup_name):
    text = path.read_text()
    if old not in text or new in text:
        return
    shutil.copy2(path, backup / backup_name)
    path.write_text(text.replace(old, new, 1))

patch(
    hxsl / "hxsl/Shader.hx",
    "\t#if debug\n\tpublic function getDebugShaderCode( bytecode = false ) {",
    "\tpublic function invalidate():Void { instance = null; }\n\n\tpublic function clone(?c:Shader):Shader {\n\t\tvar cl = Type.getClass(this);\n\t\tvar n = (c != null) ? c : Type.createEmptyInstance(cast cl);\n\t\tfor (field in Type.getClassFields(cl)) Reflect.setField(n, field, Reflect.getProperty(this, field));\n\t\treturn n;\n\t}\n\n\t#if debug\n\tpublic function getDebugShaderCode( bytecode = false ) {",
    "hxsl-Shader.hx",
)
patch(
    h3d / "h3d/impl/Stage3dDriver.hx",
    'v = ctx.createVertexBuffer(count, stride, isDynamic?"dynamicDraw":"staticDraw" );',
    'v = ctx.createVertexBuffer(count, stride, cast (isDynamic ? "dynamicDraw" : "staticDraw") );',
    "Stage3dDriver.hx",
)
patch(
    h3d / "hxd/DrawProfiler.hx",
    "d.shader.getInstance().id",
    "d.shader.getInstance().curShaderId",
    "DrawProfiler.hx",
)
PY

args=(haxelib run openfl update application.xml flash)
[ "$mode" = debug ] && args+=( -debug )
"${args[@]}"

python3 - "bin/flash/obj/assets.swf" <<'PY'
from pathlib import Path
import sys
import zlib

path = Path(sys.argv[1])
data = path.read_bytes()
if data[:3] == b"CWS":
    path.write_bytes(b"FWS" + data[3:8] + zlib.decompress(data[8:]))
PY

hxml="bin/flash/haxe/$mode.hxml"
out="bin/flash/bin/$output"
rm -f "$out"
haxe -D no-swf-compress "$hxml"

signature="$(LC_ALL=C head -c 3 "$out")"
[ "$signature" = "FWS" ] || [ "$signature" = "CWS" ]
