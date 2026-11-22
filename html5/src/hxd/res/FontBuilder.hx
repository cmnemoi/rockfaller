package hxd.res;

typedef FontBuildOptions = {
	?antiAliasing:Bool,
	?chars:String,
	?alphaPremultiplied:Bool,
	?noRetain:Bool,
	?to4444:Bool,
};

/**
 * The fork's FontBuilder draws each character of a vector font with a Flash TextField, packs the glyphs
 * into one texture and makes an h2d.Font of them. This one does the same with Canvas 2D.
 * The browser must have loaded the font first (FontBuilder.load): otherwise getFont fails and names it,
 * rather than drawing with a fallback font.
 * @spec html5.h2d.text::font-built-like-fork
 */
@:access(h2d.Font)
class FontBuilder {
	static var FONTS = new Map<String, h2d.Font>();
	static var FONT_ALIASES = new Map<String, String>();

	#if js
	public static function load(name:String, url:String):js.lib.Promise<Dynamic> {
		var face = new js.html.FontFace(name, 'url($url)');
		return face.load().then(function(loaded) {
			(cast js.Browser.document).fonts.add(loaded);
			return loaded;
		});
	}
	#end

	public static function getFont(name:String, size:Int, ?options:FontBuildOptions):h2d.Font {
		var name = FONT_ALIASES.exists(name) ? FONT_ALIASES.get(name) : name;
		var chars = options == null || options.chars == null ? hxd.Charset.DEFAULT_CHARS : options.chars;
		var key = name + "#" + size + "#" + chars;
		var font = FONTS.get(key);
		if (font == null) {
			font = build(name, size, chars);
			FONTS.set(key, font);
		}
		return font;
	}

	/** Registers a font made elsewhere (mt.heaps.TileFont), like the fork. */
	public static function addFont(name:String, font:h2d.Font) {
		FONTS.set(name, font);
	}

	public static function addFontAlias(name:String, realName:String) {
		FONT_ALIASES.set(name, realName);
	}

	public static function deleteFont(font:h2d.Font) {
		for (key in FONTS.keys())
			if (FONTS.get(key) == font)
				FONTS.remove(key);
	}

	public static function dispose() {
		FONTS = new Map();
	}

	#if js
	static function build(name:String, size:Int, chars:String):h2d.Font {
		var cssFont = size + 'px "' + name + '"';
		var document:Dynamic = js.Browser.document;
		// document.fonts.check() answers true for a family it does not know: it would draw with a fallback font.
		if (!isLoaded(name))
			throw 'Font "$name" is not loaded: call FontBuilder.load before FontBuilder.getFont';

		var canvas = js.Browser.document.createCanvasElement();
		var context = canvas.getContext2d();
		context.font = cssFont;
		var font = new h2d.Font(name, size);
		font.lineHeight = 0;

		// Same sizes as the fork: the advance rounded up, plus one pixel; a character 1 px wide has no glyph.
		var codes = [for (index in 0...chars.length) chars.charCodeAt(index)];
		var sizes:Array<{w:Int, h:Int}> = [];
		var surface = 0;
		for (index in 0...codes.length) {
			var metrics:Dynamic = context.measureText(String.fromCharCode(codes[index]));
			var w = Math.ceil(metrics.width) + 1;
			if (w == 1) continue;
			var h = Math.ceil(metrics.fontBoundingBoxAscent + metrics.fontBoundingBoxDescent) + 1;
			surface += (w + 4) * (h + 4);
			if (h > font.lineHeight) font.lineHeight = h;
			sizes[index] = {w: w, h: h};
		}

		// Same packing as the fork: a power-of-two square, then halved while it holds, doubled when full.
		var side = Math.ceil(Math.sqrt(surface));
		var width = 1;
		while (side > width) width <<= 1;
		var height = width;
		while (width * height >> 1 > surface) height >>= 1;
		var placed:Array<{code:Int, x:Int, y:Int, w:Int, h:Int}> = null;
		while (placed == null) {
			placed = [];
			var x = 0, y = 0, lineH = 0;
			for (index in 0...codes.length) {
				var size = sizes[index];
				if (size == null) continue;
				x += 4;
				if (x + size.w > width) {
					x = 0;
					y += lineH + 1;
				}
				if (y + size.h > height) {
					height <<= 1;
					placed = null;
					break;
				}
				placed.push({code: codes[index], x: x, y: y, w: size.w, h: size.h});
				if (size.h + 4 > lineH) lineH = size.h + 4;
				x += size.w + 4;
			}
		}

		canvas.width = width;
		canvas.height = height;
		context.font = cssFont;
		context.fillStyle = "#FFFFFF";
		context.textBaseline = "top";
		for (glyph in placed)
			context.fillText(String.fromCharCode(glyph.code), glyph.x, glyph.y);
		// The texture is made once the glyphs are drawn, so PixiJS never uploads an empty canvas.
		var texture = h3d.mat.Texture.fromPixi(atlasTexture(canvas));
		for (glyph in placed) {
			var tile = new h2d.Tile(texture, glyph.x, glyph.y, glyph.w - 1, glyph.h - 1);
			font.glyphs.set(glyph.code, new h2d.Font.FontChar(tile, glyph.w - 1));
		}
		font.tile = h2d.Tile.fromTexture(texture);
		return font;
	}

	static function isLoaded(name:String):Bool {
		var faces:Dynamic = (cast js.Browser.document).fonts;
		var loaded = false;
		faces.forEach(function(face:Dynamic) {
			if (face.family == name || face.family == '"$name"')
				loaded = loaded || face.status == "loaded";
		});
		return loaded;
	}

	static function atlasTexture(canvas:js.html.CanvasElement):pixi.core.textures.BaseTexture {
		var texture = pixi.core.textures.BaseTexture.from(canvas);
		texture.mipmap = pixi.core.Pixi.MipmapModes.OFF;
		return texture;
	}
	#else
	static function build(name:String, size:Int, chars:String):h2d.Font {
		throw "Font building needs a browser (Canvas 2D)";
	}
	#end
}
