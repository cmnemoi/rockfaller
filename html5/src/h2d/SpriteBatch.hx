package h2d;

// BatchElement and the element list are the fork's (delahee/h3d, BSD), unchanged.

private class ElementsIterator {
	var e : BatchElement;

	public inline function new(e) {
		this.e = e;
	}
	public inline function hasNext() {
		return e != null;
	}
	public inline function next() {
		var n = e;
		e = @:privateAccess e.next;
		return n;
	}
}

@:allow(h2d.SpriteBatch)
class BatchElement {

	/**
	 * call changePriority to update the priorty
	 */
	public var priority(default,null) : Int;

	public var x : hxd.Float32;
	public var y : hxd.Float32;

	public var scaleX : hxd.Float32;
	public var scaleY : hxd.Float32;

	public var skewX : hxd.Float32;
	public var skewY : hxd.Float32;

	//setting this will trigger parent property
	public var rotation : hxd.Float32;

	public var visible : Bool;
	public var alpha : Float;
	public var tile : Tile;
	public var color : h3d.Vector;
	public var batch(default, null) : SpriteBatch;

	var prev : BatchElement;
	var next : BatchElement;

	@:noDebug
	inline function new( t : h2d.Tile) {
		x = 0; y = 0; alpha = 1;
		rotation = 0; scaleX = scaleY = 1; skewX = 0; skewY = 0;
		priority = 0;
		color = new h3d.Vector(1, 1, 1, 1);
		tile = t;
		visible = true;
	}

	@:noDebug
	public function remove() {
		if(batch!=null)	batch.delete(this);
		tile = null;
		batch = null;
	}

	public var width(get, set):Float;
	public var height(get, set):Float;

	inline function get_width() return scaleX * tile.width;
	inline function get_height() return scaleY * tile.height;

	inline function set_width(w:Float) {
		scaleX = w / tile.width;
		return w;
	}

	inline function set_height(h:Float) {
		scaleY = h / tile.height;
		return h;
	}
	
	public function setSize(w:Float, h:Float) : Void {
		set_width(w);
		set_height(h);
	}

	public inline function setScale(v:hxd.Float32) {
		scaleX = v;
		scaleY = v;
	}

	public inline function scale(v:hxd.Float32) {
		scaleX *= v;
		scaleY *= v;
	}

	public inline function setPos(x:hxd.Float32, y:hxd.Float32) {
		this.x = x;
		this.y = y;
	}

	public inline function setColor(c:Int, ?a:Float = 1.0) {
		color.setColor((c & 0xffffff) | (0xff << 24) );
		color.a = a;
	}
	
	public inline function changePriority(v) {
		this.priority = v;
		if ( batch != null)
		{
			batch.delete(this);
			batch.add( this, v );
		}
		return v;
	}

}

/** The fork's SpriteBatch without its GPU buffers: its elements become quads in the RenderContext. */
class SpriteBatch extends Drawable {
	static inline var MAX_ELEMENTS = 4096;

	public var tile : Tile;
	public var length(default, null) : Int = 0;

	var first : BatchElement;
	var last : BatchElement;
	var optimized = false;
	var computed = false;
	var quads : Array<RenderContext.DrawCommand> = [];
	var tmpMatrix = new Matrix();

	public function new(masterTile:h2d.Tile, ?parent : h2d.Sprite) {
		super(parent);

		if ( masterTile == null ) throw "masterTile is mandatory";

		var t = masterTile.clone();
		t.dx = 0;
		t.dy = 0;
		tile = t;
	}

	public inline function nbQuad() return length;

	public override function dispose() {
		super.dispose();
		removeAllElements();
		tile = null;
		first = null;
		last = null;
	}

	/** @spec html5.h2d.batch::static-until-invalidate: a static batch keeps its quads until invalidate(). */
	public function optimizeForStatic(onOff) {
		invalidate();
		optimized = onOff;
	}

	public function removeAllElements() {
		for( e in getElements() )
			e.remove();
	}

	public inline function invalidate() {
		computed = false;
	}

	public inline function getElements() {
		return new ElementsIterator(first);
	}

	/** @spec html5.h2d.batch::elements-in-list-order */
	override function draw( ctx : RenderContext ) {
		if ( first == null ) return;
		if ( !computed || !optimized ) {
			quads = computeQuads();
			computed = true;
		}
		// @spec html5.h2d.batch::too-many-elements-draws-nothing
		if ( nbQuad() > MAX_ELEMENTS ) {
			#if debug
			throw "SpriteBatch asssertion : too many elements..." + nbQuad() + " is too much";
			#else
			return;
			#end
		}
		for ( quad in quads )
			ctx.drawQuad(this, quad);
	}

	function computeQuads() : Array<RenderContext.DrawCommand> {
		var computedQuads = [];
		var e = first;
		while ( e != null ) {
			if ( e.visible && e.tile != null )
				computedQuads.push(quadOf(e));
			e = e.next;
		}
		return computedQuads;
	}

	/** @spec html5.h2d.batch::element-drawn-through-batch: the fork's pushElemSRT, as a corner and two axes. */
	function quadOf( e : BatchElement ) : RenderContext.DrawCommand {
		var t = e.tile;
		tmpMatrix.identity();
		tmpMatrix.skew(e.skewX, e.skewY);
		tmpMatrix.scale(e.scaleX, e.scaleY);
		tmpMatrix.rotate(e.rotation);
		tmpMatrix.translate(e.x, e.y);
		return {
			texture: t.getTexture(),
			cutX: t.x,
			cutY: t.y,
			cutWidth: t.width,
			cutHeight: t.height,
			a: tmpMatrix.a,
			b: tmpMatrix.b,
			c: tmpMatrix.c,
			d: tmpMatrix.d,
			tx: tmpMatrix.transformX(t.dx, t.dy),
			ty: tmpMatrix.transformY(t.dx, t.dy),
			alpha: e.alpha,
			vertexColor: e.color == null ? null : e.color.clone(),
		};
	}

	@:noDebug
	public function add(e:BatchElement, ?prio=0) {
		invalidate();

		e.batch = this;
		e.priority = prio;

		//if ( prio == null )	{
			//if( first == null )
				//first = last = e;
			//else {
				//last.next = e;
				//e.prev = last;
				//last = e;
			//}
		//}
		//else {
			if( first == null ){
				first = last = e;
			}
			else {
				var cur = first;
				while ( e.priority <= cur.priority && cur.next != null) // Modified by Seb
					cur = cur.next;

				if ( cur.next == null ) {
					if ( cur.priority >= e.priority) {
						cur.next = e;
						e.prev = cur;

						if( last == cur)
							last = e;
						if ( first == cur )
							first = cur;
					}
					else {
						e.next = cur;
						e.prev = cur.prev;
						if( cur.prev!=null)
							cur.prev.next = e;
						cur.prev = e;
						if( first ==cur )
							first = e;
						if( last == cur )
							last = cur;
					}
				}
				else {
					var p = cur.prev;
					var n = cur;
					e.next = cur;
					cur.prev = e;
					e.prev = p;
					if ( p != null)
						p.next = e;

					if ( p == null )
						first = e;
				}
			}
		//}
		length++;
		return e;
	}

	/**
	 * no prio, means sprite will be pushed to back
	 * priority means higher is farther
	 */
	@:noDebug
	public inline function alloc(?t:h2d.Tile,?prio:Int) {
		return add(new BatchElement(t==null?tile:t), prio);
	}

	@:allow(h2d.BatchElement)
	@:noDebug
	function delete(e : BatchElement) {
		if( e.prev == null ) {
			if( first == e )
				first = e.next;
		} else
			e.prev.next = e.next;
		if( e.next == null ) {
			if( last == e )
				last = e.prev;
		} else
			e.next.prev = e.prev;

		e.prev = null;
		e.next = null;
		length--;
	}


}
