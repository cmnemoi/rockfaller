package h2d;

/**
 * What the fork keeps in a drawable's shader: its alpha and colors.
 * Drawables can share one, like a Text and its glyphs: setting one's alpha sets the other's.
 */
class DrawableShader {
	public var alpha:Float = 1.0;
	public var colorMul:h3d.Vector;
	public var colorAdd:h3d.Vector;
	public var colorMatrix:h3d.Matrix;

	public function new() {}
}

/**
 * Replaces the fork's GPU Drawable: a sprite that draws tiles. Drawing records a command in the RenderContext.
 * Color and filter are kept but not drawn yet (step 3).
 */
class Drawable extends Sprite {
	public var shader(default, null):DrawableShader;
	public var color(get, set):h3d.Vector;
	public var colorAdd(get, set):h3d.Vector;
	public var colorMatrix(get, set):h3d.Matrix;
	public var alpha(get, set):Float;
	public var filter:Bool;
	public var blendMode:BlendMode;
	/** The fork batches quads when emit is set; the PixiJS layer draws every tile the same way. */
	public var emit:Bool;

	function new(parent:Sprite, ?sh:DrawableShader) {
		super(parent);
		blendMode = Normal;
		shader = (sh == null) ? new DrawableShader() : sh;
		shader.alpha = 1.0;
		filter = false;
	}

	function get_alpha():Float return shader.alpha;
	function set_alpha(v:Float):Float return shader.alpha = v;
	function get_color():h3d.Vector return shader.colorMul;
	function set_color(v:h3d.Vector):h3d.Vector return shader.colorMul = v;
	function get_colorAdd():h3d.Vector return shader.colorAdd;
	function set_colorAdd(v:h3d.Vector):h3d.Vector return shader.colorAdd = v;
	function get_colorMatrix():h3d.Matrix return shader.colorMatrix;
	function set_colorMatrix(v:h3d.Matrix):h3d.Matrix return shader.colorMatrix = v;

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
