package h3d.mat;

/**
 * Replaces the fork's GPU texture: a size, and in the browser the PixiJS texture it shows.
 * The size alone is enough for the h2d layer's geometry, so it runs without PixiJS in tests.
 */
class Texture {
	public var width(default, null):Int;
	public var height(default, null):Int;
	/** For a texture of one color (Tile.fromColor): 0xAARRGGBB. */
	public var color(default, null):Null<Int>;
	/** The image's pixels, kept when the game reads them back (mt.Assets.getTile(path, true)). */
	public var bmp:TexturePixels;
	/** The fork's CPU copy of the pixels; the game only sets it to null to free it. */
	public var pixels:Dynamic;
	/** The fork's texture flags: the game marks some textures NoGC, never to be freed. */
	public var flags:haxe.EnumFlags<h3d.mat.Data.TextureFlags>;
	var disposed = false;
	#if pixijs
	public var pixiTexture(default, null):pixi.core.textures.BaseTexture;
	#end

	static var whiteTexture:Texture;

	/** A white texture, for tiles of one color: the fork's Tile.fromColor. */
	public static function white():Texture {
		if (whiteTexture == null) {
			#if pixijs
			whiteTexture = fromPixi(pixi.core.textures.Texture.WHITE.baseTexture);
			#else
			whiteTexture = new Texture(1, 1);
			#end
		}
		return whiteTexture;
	}

	/** @spec html5.assets::color-tile: the fork's Tile.fromColor makes a texture of that color, of that size. */
	public static function fromColor(color:Int, width:Int, height:Int):Texture {
		var texture = new Texture(width, height);
		texture.color = color;
		#if pixijs
		var canvas = js.Browser.document.createCanvasElement();
		canvas.width = width;
		canvas.height = height;
		var context = canvas.getContext2d();
		context.fillStyle = 'rgba(${(color >> 16) & 0xFF}, ${(color >> 8) & 0xFF}, ${color & 0xFF}, ${((color >>> 24) & 0xFF) / 255})';
		context.fillRect(0, 0, width, height);
		texture.pixiTexture = pixi.core.textures.BaseTexture.from(canvas);
		#end
		return texture;
	}

	/**
	 * Like the fork, the game frees textures it does not show (SubLoader) and reallocates them when they come back.
	 * PixiJS frees the GPU copy, and uploads it again by itself at the next use.
	 */
	public function dispose() {
		disposed = true;
		#if pixijs
		if (pixiTexture != null) pixiTexture.dispose();
		#end
	}

	/** Frees the texture for good (the game's avatar cache): the GPU copy, and the CPU pixels kept for reading. */
	public function destroy(?alsoCpuCopy:Bool) {
		dispose();
		bmp = null;
		pixels = null;
	}

	public function isDisposed():Bool {
		return disposed;
	}

	public function realloc() {
		disposed = false;
	}

	public function new(width:Int, height:Int) {
		flags = new haxe.EnumFlags();
		this.width = width;
		this.height = height;
	}

	#if pixijs
	/** A picture drawn on a canvas at run time (the tutorial's spotlight mask). */
	public static function fromCanvas(canvas:js.html.CanvasElement):Texture {
		var pixiTexture = pixi.core.textures.BaseTexture.from(canvas);
		pixiTexture.mipmap = pixi.core.Pixi.MipmapModes.OFF;
		return fromPixi(pixiTexture);
	}

	/** A downloaded image (a friend's avatar), without mipmaps like the atlases. */
	public static function fromImage(image:js.html.Image):Texture {
		var pixiTexture = pixi.core.textures.BaseTexture.from(image);
		pixiTexture.mipmap = pixi.core.Pixi.MipmapModes.OFF;
		return fromPixi(pixiTexture);
	}

	public static function fromPixi(pixiTexture:pixi.core.textures.BaseTexture):Texture {
		var texture = new Texture(Std.int(pixiTexture.width), Std.int(pixiTexture.height));
		texture.pixiTexture = pixiTexture;
		return texture;
	}
	#end
}

/** An image's RGBA bytes, read like Flash's BitmapData.getPixel: 0xRRGGBB, without alpha. */
class TexturePixels {
	var width:Int;
	var rgba:Array<Int>;

	public function new(width:Int, rgba:Array<Int>) {
		this.width = width;
		this.rgba = rgba;
	}

	/** @spec html5.assets::pixels-like-flash */
	public function getPixel(x:Int, y:Int):Int {
		var index = (y * width + x) * 4;
		return (rgba[index] << 16) | (rgba[index + 1] << 8) | rgba[index + 2];
	}
}
