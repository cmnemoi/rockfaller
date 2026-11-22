/**
 * The assets the JS build has preloaded. The game reads its assets synchronously (mt.Assets, openfl.Assets),
 * like Flash did with embedded ones, so the loading screen fetches them all first. One not preloaded fails and names its path.
 * @spec html5.assets::preloaded-before-use
 */
class AssetStore {
	static var textures = new Map<String, {texture:h3d.mat.Texture, pixels:Array<Int>}>();
	static var texts = new Map<String, String>();
	static var fontFamilies = new Map<String, String>();

	/** pixels: the RGBA bytes, kept only when the game reads them back (mt.Assets.getTile(path, true)). */
	public static function addTexture(path:String, texture:h3d.mat.Texture, ?pixels:Array<Int>) {
		textures.set(path, {texture: texture, pixels: pixels});
	}

	public static function addText(path:String, text:String) {
		texts.set(path, text);
	}

	public static function addFont(path:String, family:String) {
		fontFamilies.set(path, family);
	}

	public static function texture(path:String):h3d.mat.Texture {
		return textureEntry(path).texture;
	}

	public static function pixels(path:String):Array<Int> {
		return textureEntry(path).pixels;
	}

	public static function text(path:String):String {
		if (!texts.exists(path))
			throw 'Asset "$path" is not preloaded';
		return texts.get(path);
	}

	public static function fontFamily(path:String):String {
		if (!fontFamilies.exists(path))
			throw 'Font "$path" is not preloaded';
		return fontFamilies.get(path);
	}

	static function textureEntry(path:String) {
		if (!textures.exists(path))
			throw 'Image "$path" is not preloaded';
		return textures.get(path);
	}
}
