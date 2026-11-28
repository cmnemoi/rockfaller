package h2d;

private typedef FilledRectangle = {x:Float, y:Float, width:Float, height:Float, color:h3d.Vector};

/**
 * The fork's h2d.Graphics, as far as the game uses it: filled rectangles (the transition's black screen
 * of ProcessManager). Each one is drawn as a quad of the white texture tinted by its fill color.
 * The fork's lines, circles and polygons are not ported: a call to them fails at compile time.
 * @spec html5.h2d.graphics::filled-rectangles
 */
class Graphics extends Drawable {
	var rectangles:Array<FilledRectangle> = [];
	var fillColor:h3d.Vector;

	public function new(?parent) {
		super(parent);
	}

	public function clear() {
		rectangles = [];
	}

	/** Like the fork, the color's top byte is not its alpha: alpha is the second argument. */
	public function beginFill(color:Int = 0, ?alpha = 1.) {
		fillColor = new h3d.Vector(((color >> 16) & 0xFF) / 255., ((color >> 8) & 0xFF) / 255., (color & 0xFF) / 255., alpha);
	}

	public function endFill() {
		fillColor = null;
	}

	public function drawRect(x:Float, y:Float, w:Float, h:Float) {
		if (fillColor != null)
			rectangles.push({x: x, y: y, width: w, height: h, color: fillColor});
	}

	override function getBoundsRec(relativeTo, out) {
		super.getBoundsRec(relativeTo, out);
		for (rectangle in rectangles)
			addBounds(relativeTo, out, rectangle.x, rectangle.y, rectangle.width, rectangle.height);
	}

	override function draw(ctx:RenderContext) {
		for (rectangle in rectangles)
			ctx.drawQuad(this, ctx.quadFor(h3d.mat.Texture.white(), 0, 0, 1, 1, rectangle.width, 0, 0, rectangle.height, rectangle.x, rectangle.y,
				1.0, rectangle.color));
	}
}
