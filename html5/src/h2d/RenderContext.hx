package h2d;

/** One tile to draw: its cut in the texture, and where (the 2D matrix of its top-left corner). */
typedef DrawCommand = {
	texture:h3d.mat.Texture,
	cutX:Int,
	cutY:Int,
	cutWidth:Int,
	cutHeight:Int,
	a:Float,
	b:Float,
	c:Float,
	d:Float,
	tx:Float,
	ty:Float,
	alpha:Float,
	?blendMode:BlendMode,
}

/**
 * Replaces the fork's GPU render context: drawing a tile records a command, in drawing order.
 * PixiRenderer shows the commands in the browser; the tests read them.
 */
class RenderContext {
	public var frame:Int;
	public var drawn(default, null):Array<DrawCommand>;

	public function new() {
		frame = 0;
		drawn = [];
	}

	public function startFrame() {
		frame++;
		drawn = [];
	}

	/** Same corner and axes as the fork's Drawable.emitTile: a tile is a quad with no transform of its own. */
	public function drawTile(drawable:Drawable, tile:Tile) {
		drawQuad(drawable, {
			texture: tile.getTexture(),
			cutX: tile.x,
			cutY: tile.y,
			cutWidth: tile.width,
			cutHeight: tile.height,
			a: 1, b: 0, c: 0, d: 1,
			tx: tile.dx,
			ty: tile.dy,
			alpha: 1.0,
		});
	}

	/** Draws a quad given in the drawable's space (like a batch element's), through the drawable's absolute matrix. */
	public function drawQuad(drawable:Drawable, quad:DrawCommand) {
		drawn.push({
			texture: quad.texture,
			cutX: quad.cutX,
			cutY: quad.cutY,
			cutWidth: quad.cutWidth,
			cutHeight: quad.cutHeight,
			a: drawable.matA * quad.a + drawable.matC * quad.b,
			b: drawable.matB * quad.a + drawable.matD * quad.b,
			c: drawable.matA * quad.c + drawable.matC * quad.d,
			d: drawable.matB * quad.c + drawable.matD * quad.d,
			tx: drawable.absX + quad.tx * drawable.matA + quad.ty * drawable.matC,
			ty: drawable.absY + quad.tx * drawable.matB + quad.ty * drawable.matD,
			alpha: quad.alpha * drawable.alpha,
			blendMode: drawable.blendMode,
		});
	}
}
