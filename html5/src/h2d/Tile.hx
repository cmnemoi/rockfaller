package h2d;

/**
 * The fork's h2d.Tile without the GPU: a cut (x, y, cutWidth, cutHeight) of a texture, drawn width x height
 * and shifted by (dx, dy). The cut is the fork's UVs: scaleToSize changes the drawn size only, so a resized
 * bitmap font draws whole letters, shrunk.
 * The methods are the fork's, ported as the game needs them; a missing one fails at compile time.
 * @spec html5.h2d::tile-size-like-fork
 */
@:allow(h2d)
class Tile {
	var innerTex:h3d.mat.Texture;

	public var dx:Int;
	public var dy:Int;
	public var x(default, null):Int;
	public var y(default, null):Int;
	public var width:Int;
	public var height:Int;
	var cutWidth:Int;
	var cutHeight:Int;

	public inline function new(tex:h3d.mat.Texture, x:Int, y:Int, w:Int, h:Int, dx = 0, dy = 0) {
		this.innerTex = tex;
		this.x = x;
		this.y = y;
		this.width = cutWidth = w;
		this.height = cutHeight = h;
		this.dx = dx;
		this.dy = dy;
	}

	public static function fromTexture(tex:h3d.mat.Texture):Tile {
		return new Tile(tex, 0, 0, tex.width, tex.height);
	}

	/** @spec html5.assets::color-tile */
	public static function fromColor(color:Int, ?width = 4, ?height = 4):Tile {
		return fromTexture(h3d.mat.Texture.fromColor(color, width, height));
	}

	public function getTexture():h3d.mat.Texture {
		return innerTex;
	}

	public function setTexture(tex:h3d.mat.Texture) {
		this.innerTex = tex;
	}

	public function sub(x:Int, y:Int, w:Int, h:Int, dx = 0, dy = 0):Tile {
		return new Tile(innerTex, this.x + x, this.y + y, w, h, dx, dy);
	}

	public inline function center(?dx:Int, ?dy:Int):Tile {
		if (dx == null) dx = width >> 1;
		if (dy == null) dy = height >> 1;
		return sub(0, 0, width, height, -dx, -dy);
	}

	public inline function centerRatio(?px:Float = 0.5, ?py:Float = 0.5):Tile {
		return sub(0, 0, width, height, -Std.int(px * width), -Std.int(py * height));
	}

	public inline function setCenter(?dx:Int, ?dy:Int):Void
		copy(center(dx, dy));

	public inline function setCenterRatio(?px:Float = 0.5, ?py:Float = 0.5):Void
		copy(centerRatio(px, py));

	public function setPos(x, y) {
		this.x = x;
		this.y = y;
	}

	public function setSize(w, h) {
		this.width = cutWidth = w;
		this.height = cutHeight = h;
	}

	public function scaleToSize(w, h) {
		//there are information lost here...
		dx = Math.round(dx * w / width);
		dy = Math.round(dy * h / height);

		this.width = w;
		this.height = h;
	}

	/** How much the cut is stretched to be drawn width wide; an empty cut draws nothing, whatever the stretch. */
	function stretchX():Float {
		return cutWidth == 0 ? 1.0 : width / cutWidth;
	}

	function stretchY():Float {
		return cutHeight == 0 ? 1.0 : height / cutHeight;
	}

	/** The fork frees the GPU texture; here the tile only lets it go. */
	public function dispose() {
		innerTex = null;
	}

	public inline function clone() {
		var tile = new Tile(innerTex, x, y, width, height, dx, dy);
		tile.cutWidth = cutWidth;
		tile.cutHeight = cutHeight;
		return tile;
	}

	/** Like the fork, copies everything but x and y. */
	public inline function copy(t:Tile) {
		innerTex = t.innerTex;
		dx = t.dx;
		dy = t.dy;
		width = t.width;
		height = t.height;
		cutWidth = t.cutWidth;
		cutHeight = t.cutHeight;
		return t;
	}

	public function toString() {
		return "Tile(" + x + "," + y + "," + width + "x" + height + (dx != 0 || dy != 0 ? "," + dx + ":" + dy : "") + ")";
	}
}
