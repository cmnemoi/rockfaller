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
	/** The mask whose red multiplies the drawn alpha, cut and laid out like the drawn tile (the fork's alphaMap). */
	?alphaMap:{texture:h3d.mat.Texture, cutX:Int, cutY:Int, cutWidth:Int, cutHeight:Int},
}

/**
 * Replaces the fork's GPU render context: drawing a tile records a command, in drawing order.
 * PixiRenderer shows the commands in the browser; the tests read them.
 * @spec html5.h2d::commands-reused: the commands, their color matrices and alpha maps are reused from frame to
 * frame, and callers give their quad in one scratch command: about 1 MB of garbage per frame came from new ones.
 */
class RenderContext {
	static inline var MATRIX_SIZE = 20;
	static inline var ROW_LENGTH = 5;
	static inline var OFFSET_COLUMN = 4;
	static inline var CHANNELS = 4;
	static inline var ALPHA = 3;

	public var frame:Int;
	public var drawn(default, null):Array<DrawCommand>;
	// What each command slot keeps from frame to frame.
	var commands:Array<DrawCommand> = [];
	var colorMatrices:Array<Array<Float>> = [];
	var alphaMaps:Array<{texture:h3d.mat.Texture, cutX:Int, cutY:Int, cutWidth:Int, cutHeight:Int}> = [];
	var scratch:DrawCommand = newCommand();

	public function new() {
		frame = 0;
		drawn = [];
	}

	public function startFrame() {
		frame++;
		drawn.resize(0);
	}

	/** The scratch quad a drawable fills, then gives to drawQuad: valid until the next call. */
	public function scratchQuad():DrawCommand {
		return scratch;
	}

	/** The scratch quad, filled with these values. */
	public function quadFor(texture:h3d.mat.Texture, cutX:Int, cutY:Int, cutWidth:Int, cutHeight:Int, a:Float, b:Float, c:Float, d:Float,
			tx:Float, ty:Float, alpha:Float, ?vertexColor:h3d.Vector):DrawCommand {
		return fillQuad(scratch, texture, cutX, cutY, cutWidth, cutHeight, a, b, c, d, tx, ty, alpha, vertexColor);
	}

	public static function fillQuad(quad:DrawCommand, texture:h3d.mat.Texture, cutX:Int, cutY:Int, cutWidth:Int, cutHeight:Int, a:Float, b:Float,
			c:Float, d:Float, tx:Float, ty:Float, alpha:Float, vertexColor:h3d.Vector):DrawCommand {
		quad.texture = texture;
		quad.cutX = cutX;
		quad.cutY = cutY;
		quad.cutWidth = cutWidth;
		quad.cutHeight = cutHeight;
		quad.a = a;
		quad.b = b;
		quad.c = c;
		quad.d = d;
		quad.tx = tx;
		quad.ty = ty;
		quad.alpha = alpha;
		quad.vertexColor = vertexColor;
		return quad;
	}

	public static function newCommand():DrawCommand {
		return {texture: null, cutX: 0, cutY: 0, cutWidth: 0, cutHeight: 0, a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0, alpha: 1, blendMode: null,
			vertexColor: null, colorMatrix: null, alphaMap: null};
	}

	/** Same corner and axes as the fork's Drawable.emitTile: a tile is a quad with no transform of its own. */
	public function drawTile(drawable:Drawable, tile:Tile) {
		drawQuad(drawable, quadFor(tile.getTexture(), tile.x, tile.y, tile.cutWidth, tile.cutHeight, tile.stretchX(), 0, 0, tile.stretchY(),
			tile.dx, tile.dy, 1.0));
	}

	/** Draws a quad given in the drawable's space (like a batch element's), through the drawable's absolute matrix. */
	public function drawQuad(drawable:Drawable, quad:DrawCommand) {
		var slot = drawn.length;
		if (slot == commands.length) {
			commands.push(newCommand());
			colorMatrices.push([for (_ in 0...MATRIX_SIZE) 0.0]);
			alphaMaps.push({texture: null, cutX: 0, cutY: 0, cutWidth: 0, cutHeight: 0});
		}
		var command = commands[slot];
		drawn.push(command);
		var alpha = quad.alpha * drawable.alpha;
		var colorMatrix = writeColorMatrix(colorMatrices[slot], quad.vertexColor, alpha, drawable.colorMatrix, drawable.color, drawable.colorAdd);
		command.texture = quad.texture;
		command.cutX = quad.cutX;
		command.cutY = quad.cutY;
		command.cutWidth = quad.cutWidth;
		command.cutHeight = quad.cutHeight;
		command.a = drawable.matA * quad.a + drawable.matC * quad.b;
		command.b = drawable.matB * quad.a + drawable.matD * quad.b;
		command.c = drawable.matA * quad.c + drawable.matC * quad.d;
		command.d = drawable.matB * quad.c + drawable.matD * quad.d;
		command.tx = drawable.absX + quad.tx * drawable.matA + quad.ty * drawable.matC;
		command.ty = drawable.absY + quad.tx * drawable.matB + quad.ty * drawable.matD;
		command.alpha = colorMatrix == null ? alpha : 1.0;
		command.blendMode = drawable.blendMode;
		command.colorMatrix = colorMatrix;
		command.alphaMap = drawable.alphaMap == null ? null : alphaMapOf(alphaMaps[slot], drawable.alphaMap);
	}

	static function alphaMapOf(into:{texture:h3d.mat.Texture, cutX:Int, cutY:Int, cutWidth:Int, cutHeight:Int}, map:Tile) {
		into.texture = map.getTexture();
		into.cutX = map.x;
		into.cutY = map.y;
		into.cutWidth = map.width;
		into.cutHeight = map.height;
		return into;
	}

	/**
	 * @spec html5.h2d.color::color-like-fork-shader: the fork's fragment shader, as one matrix, written into `into`.
	 * The shader multiplies by the vertex color, then the alpha, then col *= colorMatrix (a row vector:
	 * out_j = sum of in_i * M_ij, like h3d.Vector.transform), then the color, then adds colorAdd.
	 */
	static function writeColorMatrix(into:Array<Float>, vertexColor:h3d.Vector, alpha:Float, matrix:h3d.Matrix, multiplied:h3d.Vector,
			added:h3d.Vector):Array<Float> {
		if (matrix == null && multiplied == null && added == null && isWhite(vertexColor))
			return null;
		for (output in 0...CHANNELS) {
			for (input in 0...CHANNELS)
				into[output * ROW_LENGTH + input] = before(vertexColor, alpha, input) * entryOf(matrix, input, output) * channelOf(multiplied, output, 1.0);
			into[output * ROW_LENGTH + OFFSET_COLUMN] = channelOf(added, output, 0.0);
		}
		return into;
	}

	/** What the shader multiplies the picture by before the matrix: the vertex color, its alpha times the drawable's. */
	static inline function before(vertexColor:h3d.Vector, alpha:Float, input:Int):Float {
		var vertexFactor = channelOf(vertexColor, input, 1.0);
		return input == ALPHA ? vertexFactor * alpha : vertexFactor;
	}

	static inline function channelOf(color:h3d.Vector, channel:Int, ifNone:Float):Float {
		return color == null ? ifNone : switch (channel) {
			case 0: color.x;
			case 1: color.y;
			case 2: color.z;
			default: color.w;
		}
	}

	/** The matrix's row `input`, column `output`; no matrix is the identity. */
	static function entryOf(matrix:h3d.Matrix, input:Int, output:Int):Float {
		if (matrix == null)
			return input == output ? 1.0 : 0.0;
		return switch (input * CHANNELS + output) {
			case 0: matrix._11; case 1: matrix._12; case 2: matrix._13; case 3: matrix._14;
			case 4: matrix._21; case 5: matrix._22; case 6: matrix._23; case 7: matrix._24;
			case 8: matrix._31; case 9: matrix._32; case 10: matrix._33; case 11: matrix._34;
			case 12: matrix._41; case 13: matrix._42; case 14: matrix._43; default: matrix._44;
		}
	}

	static function isWhite(color:h3d.Vector) {
		return color == null || (color.x == 1 && color.y == 1 && color.z == 1 && color.w == 1);
	}
}
