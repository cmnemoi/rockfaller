package openfl;

/**
 * openfl.Assets, as far as the game uses it in the JS build: texts, bytes and fonts, preloaded in AssetStore.
 * OpenFL itself does not build with Haxe 4.
 */
class Assets {
	public static function getText(id:String):String {
		return AssetStore.text(id);
	}

	public static function getBytes(id:String):haxe.io.Bytes {
		return haxe.io.Bytes.ofString(AssetStore.text(id));
	}

	/** The font's family, which FontBuilder draws with once the browser has loaded it. */
	public static function getFont(id:String):{fontName:String} {
		return {fontName: AssetStore.fontFamily(id)};
	}
}
