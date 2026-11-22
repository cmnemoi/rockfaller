package h2d;

private class CoreObjects {
	public var tmpMatrix2D:Matrix;
	public var tmpMatrix2D_2:Matrix;
	public var tmpBounds:h2d.col.Bounds;

	var emptyTexture:h3d.mat.Texture;

	public function new() {
		tmpMatrix2D = new Matrix();
		tmpMatrix2D_2 = new Matrix();
		tmpBounds = new h2d.col.Bounds();
	}

	public function getEmptyTexture() {
		if (emptyTexture == null)
			emptyTexture = new h3d.mat.Texture(1, 1);
		return emptyTexture;
	}
}

/** Replaces the fork's Tools: the shared scratch objects, without GPU buffers. */
class Tools {
	static var CORE:CoreObjects = null;

	public static function getEmptyTexture() return getCoreObjects().getEmptyTexture();

	public static function getCoreObjects():CoreObjects {
		if (CORE == null) CORE = new CoreObjects();
		return CORE;
	}
}
