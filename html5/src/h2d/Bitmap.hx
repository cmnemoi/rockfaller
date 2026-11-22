package h2d;

/** The fork's h2d.Bitmap, without its GPU helpers (BitmapData, Pixels, OpenFL assets). */
class Bitmap extends Drawable {
	public var tile:Tile;

	public function new(?tile:Tile, ?parent:Sprite, ?sh:Drawable.DrawableShader) {
		super(parent, sh);
		this.tile = tile;
	}

	override function getBoundsRec(relativeTo, out) {
		super.getBoundsRec(relativeTo, out);
		if (tile != null) addBounds(relativeTo, out, tile.dx, tile.dy, tile.width, tile.height);
	}

	public override function clone<T>(?s:T):T {
		var b:Bitmap = (s == null) ? new Bitmap(tile, parent, null) : cast s;
		return cast b;
	}

	override function draw(ctx:RenderContext) {
		if (tile == null) return;

		if (canEmit()) emitTile(ctx, tile);
		else drawTile(ctx, tile);
	}

	public override function set_width(w:Float):Float {
		scaleX = w / tile.width;
		return w;
	}

	public override function set_height(h:Float):Float {
		scaleY = h / tile.height;
		return h;
	}

	public static inline function fromTexture(tex:h3d.mat.Texture, ?parent) {
		return new Bitmap(new Tile(tex, 0, 0, tex.width, tex.height), parent);
	}
}
