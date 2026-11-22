package h3d.mat;

/**
 * Replaces the fork's GPU texture: a size, and in the browser the PixiJS texture it shows.
 * The size alone is enough for the h2d layer's geometry, so it runs without PixiJS in tests.
 */
class Texture {
	public var width(default, null):Int;
	public var height(default, null):Int;
	#if pixijs
	public var pixiTexture(default, null):pixi.core.textures.BaseTexture;
	#end

	public function new(width:Int, height:Int) {
		this.width = width;
		this.height = height;
	}

	#if pixijs
	public static function fromPixi(pixiTexture:pixi.core.textures.BaseTexture):Texture {
		var texture = new Texture(Std.int(pixiTexture.width), Std.int(pixiTexture.height));
		texture.pixiTexture = pixiTexture;
		return texture;
	}
	#end
}
