package tools;

/**
 * Checks how the JS build serves the game's assets once preloaded: mt.Assets, openfl.Assets and Tile.fromColor.
 * Run: mise run html5:check:assets (compiled to JS, run by Node)
 */
class AssetCheck {
	static function main() {
		aColorTileHasTheAskedSize();
		aPreloadedImageGivesItsTile();
		anImageNotPreloadedFailsWithItsPath();
		aRetainedImageReadsItsPixelsLikeFlash();
		aPreloadedTextIsReadAsTextAndAsBytes();
		aTextNotPreloadedFailsWithItsPath();
		aPreloadedFontIsFoundByItsFileName();
		trace("PASS");
	}

	/** @spec html5.assets::color-tile */
	static function aColorTileHasTheAskedSize() {
		var tile = h2d.Tile.fromColor(0xFF000000, 640, 768);

		check(tile.width == 640 && tile.height == 768 && tile.dx == 0 && tile.dy == 0, "a color tile is 640 x 768, with no offset");
		check(tile.getTexture().color == 0xFF000000, "its texture is opaque black (got " + StringTools.hex(tile.getTexture().color) + ")");
	}

	/** @spec html5.assets::preloaded-before-use */
	static function aPreloadedImageGivesItsTile() {
		AssetStore.addTexture("design.png", new h3d.mat.Texture(1024, 512));

		var tile = mt.Assets.getTile("design.png")();

		check(tile.width == 1024 && tile.height == 512, "design.png gives a 1024 x 512 tile");
	}

	/** @spec html5.assets::preloaded-before-use */
	static function anImageNotPreloadedFailsWithItsPath() {
		checkFailsWith(function() mt.Assets.getTile("platypus.png")(), "platypus.png", "an image not preloaded fails with its path");
	}

	/** @spec html5.assets::pixels-like-flash: ButtonLevel finds the map's red markers this way */
	static function aRetainedImageReadsItsPixelsLikeFlash() {
		// 2 x 1 pixels, RGBA: a red one, then a half-transparent blue one.
		var texture = new h3d.mat.Texture(2, 1);
		AssetStore.addTexture("levels.png", texture, [0xFF, 0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF, 0x80]);

		var tile = mt.Assets.getTile("levels.png", true)();
		var pixels = tile.getTexture().bmp;

		check(pixels.getPixel(0, 0) == 0xFF0000, "the first pixel reads red, without alpha like Flash's getPixel (got " + StringTools.hex(pixels.getPixel(0, 0)) + ")");
		check(pixels.getPixel(1, 0) == 0x0000FF, "the second reads blue (got " + StringTools.hex(pixels.getPixel(1, 0)) + ")");
	}

	/** @spec html5.assets::preloaded-before-use */
	static function aPreloadedTextIsReadAsTextAndAsBytes() {
		AssetStore.addText("data/loot.json", '{"loot":"été"}');

		check(openfl.Assets.getText("data/loot.json") == '{"loot":"été"}', "loot.json is read as text");
		check(openfl.Assets.getBytes("data/loot.json").toString() == '{"loot":"été"}', "and as bytes, UTF-8 kept");
	}

	/** @spec html5.assets::preloaded-before-use */
	static function aTextNotPreloadedFailsWithItsPath() {
		checkFailsWith(function() openfl.Assets.getText("worlds/platypus.meta.json"), "worlds/platypus.meta.json", "a text not preloaded fails with its path");
	}

	/** @spec html5.assets::preloaded-before-use */
	static function aPreloadedFontIsFoundByItsFileName() {
		AssetStore.addFont("assets/BenchNine-Regular.ttf", "BenchNine");

		check(openfl.Assets.getFont("assets/BenchNine-Regular.ttf").fontName == "BenchNine", "the font file gives the family FontBuilder draws with");
	}

	static function checkFailsWith(action:Void->Void, expectedInMessage:String, expectation:String) {
		var message:String = null;
		try action() catch (error:Dynamic) message = Std.string(error);
		check(message != null && message.indexOf(expectedInMessage) >= 0, expectation + " (got: " + message + ")");
	}

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}
