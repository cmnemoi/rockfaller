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

	/** Same corner and axes as the fork's Drawable.emitTile. */
	public function drawTile(drawable:Drawable, tile:Tile) {
		drawn.push({
			texture: tile.getTexture(),
			cutX: tile.x,
			cutY: tile.y,
			cutWidth: tile.width,
			cutHeight: tile.height,
			a: drawable.matA,
			b: drawable.matB,
			c: drawable.matC,
			d: drawable.matD,
			tx: drawable.absX + tile.dx * drawable.matA + tile.dy * drawable.matC,
			ty: drawable.absY + tile.dx * drawable.matB + tile.dy * drawable.matD,
			alpha: drawable.alpha,
		});
	}
}
