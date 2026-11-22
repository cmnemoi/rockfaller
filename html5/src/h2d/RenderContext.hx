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
	/** A batch element's own color, multiplied with its picture (the fork's vertex color). */
	?vertexColor:h3d.Vector,
	/** PixiJS's 5 x 4 color matrix (straight colors, offsets in 0..1), or null when the picture is drawn as it is. */
	?colorMatrix:Array<Float>,
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
		var alpha = quad.alpha * drawable.alpha;
		var colorMatrix = colorMatrixOf(quad.vertexColor, alpha, drawable.colorMatrix, drawable.color, drawable.colorAdd);
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
			alpha: colorMatrix == null ? alpha : 1.0,
			blendMode: drawable.blendMode,
			colorMatrix: colorMatrix,
		});
	}

	/**
	 * @spec html5.h2d.color::color-like-fork-shader: the fork's fragment shader, as one matrix.
	 * The shader multiplies by the vertex color, then the alpha, then col *= colorMatrix (a row vector:
	 * out_j = sum of in_i * M_ij, like h3d.Vector.transform), then the color, then adds colorAdd.
	 */
	static function colorMatrixOf(vertexColor:h3d.Vector, alpha:Float, matrix:h3d.Matrix, multiplied:h3d.Vector, added:h3d.Vector):Array<Float> {
		if (matrix == null && multiplied == null && added == null && isWhite(vertexColor))
			return null;
		var before = vertexColor == null ? [1.0, 1.0, 1.0, alpha] : [vertexColor.x, vertexColor.y, vertexColor.z, vertexColor.w * alpha];
		var rows = matrix == null ? [[1.0, 0, 0, 0], [0, 1.0, 0, 0], [0, 0, 1.0, 0], [0, 0, 0, 1.0]]
			: [[matrix._11, matrix._12, matrix._13, matrix._14], [matrix._21, matrix._22, matrix._23, matrix._24],
				[matrix._31, matrix._32, matrix._33, matrix._34], [matrix._41, matrix._42, matrix._43, matrix._44]];
		var after = multiplied == null ? [1.0, 1.0, 1.0, 1.0] : [multiplied.x, multiplied.y, multiplied.z, multiplied.w];
		var offsets = added == null ? [0.0, 0, 0, 0] : [added.x, added.y, added.z, added.w];
		var pixiMatrix = [];
		for (output in 0...4) {
			for (input in 0...4)
				pixiMatrix.push(before[input] * rows[input][output] * after[output]);
			pixiMatrix.push(offsets[output]);
		}
		return pixiMatrix;
	}

	static function isWhite(color:h3d.Vector) {
		return color == null || (color.x == 1 && color.y == 1 && color.z == 1 && color.w == 1);
	}
}
