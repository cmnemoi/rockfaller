package h2d;

private typedef PlacedTile = {x:Int, y:Int, tile:Tile};

/**
 * The fork's TileGroup without its GPU buffer: tiles placed in the group's space, drawn in order.
 * Text draws its glyphs with it. rangeMin and rangeMax are left out: the game does not use them.
 */
class TileGroup extends Drawable {
	public var tile:Tile;

	var placed:Array<PlacedTile> = [];
	var xMin = Math.POSITIVE_INFINITY;
	var yMin = Math.POSITIVE_INFINITY;
	var xMax = Math.NEGATIVE_INFINITY;
	var yMax = Math.NEGATIVE_INFINITY;

	public function new(t, ?parent, ?sh:Drawable.DrawableShader) {
		tile = t;
		super(parent, sh);
	}

	override function getBoundsRec(relativeTo, out) {
		super.getBoundsRec(relativeTo, out);
		addBounds(relativeTo, out, xMin, yMin, xMax - xMin, yMax - yMin);
	}

	public function reset() {
		placed = [];
		xMin = Math.POSITIVE_INFINITY;
		yMin = Math.POSITIVE_INFINITY;
		xMax = Math.NEGATIVE_INFINITY;
		yMax = Math.NEGATIVE_INFINITY;
	}

	/** Same bounds as the fork's TileLayerContent.add. */
	public function add(x:Int, y:Int, t:Tile) {
		placed.push({x: x, y: y, tile: t});
		var sx = x + t.dx;
		var sy = y + t.dy;
		if (sx < xMin) xMin = sx;
		if (sy < yMin) yMin = sy;
		if (sx + t.width > xMax) xMax = sx + t.width;
		if (sy + t.height > yMax) yMax = sy + t.height;
	}

	public function count() {
		return placed.length;
	}

	/** An empty tile (a new line has one) draws an empty quad in the fork: it is skipped here. */
	override function draw(ctx:RenderContext) {
		for (entry in placed) {
			var t = entry.tile;
			if (t.width <= 0 || t.height <= 0) continue;
			ctx.drawQuad(this, {
				texture: t.getTexture(),
				cutX: t.x,
				cutY: t.y,
				cutWidth: t.cutWidth,
				cutHeight: t.cutHeight,
				a: t.stretchX(), b: 0, c: 0, d: t.stretchY(),
				tx: entry.x + t.dx,
				ty: entry.y + t.dy,
				alpha: 1.0,
			});
		}
	}
}
