package h2d;

/** The fork passes shaders to its drawables; the PixiJS layer has none yet, but keeps the type. */
class DrawableShader {
	public function new() {}
}

/**
 * Replaces the fork's GPU Drawable: a sprite that draws tiles. Drawing records a command in the RenderContext.
 * Color and filter are kept but not drawn yet (step 3).
 */
class Drawable extends Sprite {
	public var color:h3d.Vector;
	public var colorAdd:h3d.Vector;
	public var colorMatrix:h3d.Matrix;
	public var filter:Bool;
	public var alpha:Float;
	public var blendMode:BlendMode;

	function new(parent:Sprite, ?sh:DrawableShader) {
		super(parent);
		alpha = 1.0;
		filter = false;
		blendMode = Normal;
	}

	public override function clone<T>(?s:T):T {
		if (s == null)
			throw "impossible hierarchy cloning. Cloning not yet implemented for " + Std.string(Type.getClass(this));
		var drawable:Drawable = cast s;
		super.clone(s);
		drawable.color = color;
		drawable.colorAdd = colorAdd;
		drawable.colorMatrix = colorMatrix;
		drawable.filter = filter;
		drawable.alpha = alpha;
		drawable.blendMode = blendMode;
		return cast drawable;
	}

	public inline function canEmit() {
		return true;
	}

	function emitTile(ctx:RenderContext, tile:Tile) {
		ctx.drawTile(this, tile);
	}

	function drawTile(ctx:RenderContext, tile:Tile) {
		ctx.drawTile(this, tile);
	}
}
