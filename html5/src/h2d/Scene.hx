package h2d;

/**
 * Replaces the fork's GPU Scene: the root of the tree, which syncs then draws it into a RenderContext,
 * and dispatches the stage's pointer events to its Interactives.
 *
 * The event code is the fork's. The fork's scene puts the whole tree in GPU viewport space (-1..1, y up),
 * and its hit test works there, with an aspect correction r. This layer stays in pixels, so the hit test
 * converts the matrices to the fork's viewport space first: the fork's quirks stay (an interactive flipped
 * on one axis never gets a click, a rotated one scaled unevenly has a skewed hit area).
 * @spec html5.h2d.interactive::events-like-fork
 */
class Scene extends Sprite {
	var interactive:Array<Interactive>;
	var pendingEvents:Array<hxd.Event>;

	@:allow(h2d.Interactive)
	var currentOver:Interactive;
	@:allow(h2d.Interactive)
	var currentFocus:Interactive;

	var pushList:Array<Interactive>;
	var currentDrag:{f:hxd.Event->Void, onCancel:Void->Void, ref:Null<Int>};
	var eventListeners:Array<hxd.Event->Void>;

	public var isInteractive:Bool = true;

	public function new() {
		super(null);
		width = stage.width;
		height = stage.height;
		interactive = new Array();
		pushList = new Array();
		eventListeners = new Array();
		posChanged = true;
	}

	public function render(ctx:RenderContext) {
		ctx.startFrame();
		sync(ctx);
		drawRec(ctx);
	}

	override function sync(ctx:RenderContext) {
		if (!allocated)
			onAlloc();
		super.sync(ctx);
	}

	override function onAlloc() {
		stage.addEventTarget(onEvent);
		super.onAlloc();
	}

	override function onDelete() {
		stage.removeEventTarget(onEvent);
		super.onDelete();
	}

	function onEvent(e:hxd.Event) {
		if (pendingEvents != null) {
			e.relX = screenXToLocal(e.relX);
			e.relY = screenYToLocal(e.relY);
			pendingEvents.push(e);
		}
	}

	function screenXToLocal(mx:Float) {
		return (mx - x) * width / (stage.width * scaleX);
	}

	function screenYToLocal(my:Float) {
		return (my - y) * height / (stage.height * scaleY);
	}

	override function get_mouseX() {
		return screenXToLocal(stage.mouseX);
	}

	override function get_mouseY() {
		return screenYToLocal(stage.mouseY);
	}

	public override function set_width(w) return this.width = w;
	public override function set_height(h) return this.height = h;
	public override function get_width() return width;
	public override function get_height() return height;

	// A sprite's matrix in the fork's viewport space: its pixel matrix, then x * 2 / width - 1 and y * -2 / height + 1.
	inline function viewportA(s:Sprite) return s.matA * 2 / width;
	inline function viewportB(s:Sprite) return s.matB * -2 / height;
	inline function viewportC(s:Sprite) return s.matC * 2 / width;
	inline function viewportD(s:Sprite) return s.matD * -2 / height;
	inline function viewportX(s:Sprite) return s.absX * 2 / width - 1;
	inline function viewportY(s:Sprite) return s.absY * -2 / height + 1;

	function dispatchListeners(event:hxd.Event) {
		event.propagate = true;
		event.cancel = false;
		for (l in eventListeners) {
			l(event);
			if (!event.propagate) break;
		}
	}

	function emitEvent( event : hxd.Event ) {
		var x = event.relX, y = event.relY;
		var rx = x * viewportA(this) + y * viewportB(this) + viewportX(this);
		var ry = x * viewportC(this) + y * viewportD(this) + viewportY(this);
		var r = height / width;
		var handled = false;
		var checkOver = false, checkPush = false, cancelFocus = false;
		switch( event.kind ) {
			case EMove: checkOver = true;
			case EPush: cancelFocus = true; checkPush = true;
			case ERelease: checkPush = true;
			case EKeyUp, EKeyDown, EWheel:
				if( currentFocus != null )
					currentFocus.handleEvent(event);
				else {
					if( currentOver != null ) {
						event.propagate = true;
						currentOver.handleEvent(event);
						if( !event.propagate ) return;
					}
					dispatchListeners(event);
				}
				return;
			default:
		}
		
		for( i in interactive ) {
			// TODO : we are not sure that the positions are correctly updated !

			// this is a bit tricky since we are not in the not-euclide viewport space
			// (r = ratio correction)
			var dx = rx - viewportX(i);
			var dy = ry - viewportY(i);

			var w1 = i.width * viewportA(i) * r;
			var h1 = i.width * viewportC(i);
			var ky = h1 * dx - w1 * dy;
			// up line
			if( ky < 0 )
				continue;

			var w2 = i.height * viewportB(i) * r;
			var h2 = i.height * viewportD(i);
			var kx = w2 * dy - h2 * dx;

			// left line
			if( kx < 0 )
				continue;

			var max = h1 * w2 - w1 * h2;
			// bottom/right
			if( ky >= max || kx * r >= max )
				continue;

			// check visibility
			var visible = true;
			var p : Sprite = i;
			while( p != null ) {
				if( !p.visible ) {
					visible = false;
					break;
				}
				p = p.parent;
			}
			if( !visible ) continue;

			event.relX = (kx * r / max) * i.width;
			event.relY = (ky / max) * i.height;

			i.handleEvent(event);

			if( event.cancel ) {
				event.cancel = false;
			}
			else if( checkOver ) {
				if( currentOver != i ) {
					var old = event.propagate;
					if( currentOver != null ) {
						event.kind = EOut;
						// relX/relY is not correct here
						currentOver.handleEvent(event);
					}
					event.kind = EOver;
					event.cancel = false;
					i.handleEvent(event);
					if( event.cancel )
						currentOver = null;
					else {
						currentOver = i;
						checkOver = false;
					}
					event.kind = EMove;
					event.cancel = false;
					event.propagate = old;
				} else
					checkOver = false;
			} else {
				if( checkPush ) {
					if( event.kind == EPush )
						pushList.push(i);
					else
						pushList.remove(i);
				}
				if( cancelFocus && i == currentFocus )
					cancelFocus = false;
			}

			if( event.propagate ) {
				event.propagate = false;
				continue;
			}

			handled = true;
			break;
		}
		if( cancelFocus && currentFocus != null ) {
			event.kind = EFocusLost;
			currentFocus.handleEvent(event);
			event.kind = EPush;
		}
		if( checkOver && currentOver != null ) {
			event.kind = EOut;
			currentOver.handleEvent(event);
			event.kind = EMove;
			currentOver = null;
		}
		if( !handled ) {
			if( event.kind == EPush )
				pushList.push(null);
			dispatchListeners(event);
		}
	}

	function hasEvents() {
		return interactive.length > 0 || eventListeners.length > 0;
	}

	public function checkEvents() {
		if( pendingEvents == null || !isInteractive ) {
			if( !hasEvents() )
				return;
			pendingEvents = new Array();
		}
		var old = pendingEvents;
		if( old.length == 0 )
			return;
		pendingEvents = null;
		var ox = 0., oy = 0.;
		for( e in old ) {
			var hasPos = switch( e.kind ) {
			case EKeyUp, EKeyDown: false;
			default: true;
			}

			if( hasPos ) {
				ox = e.relX;
				oy = e.relY;
			}

			if( currentDrag != null && (currentDrag.ref == null || currentDrag.ref == e.touchId) ) {
				currentDrag.f(e);
				if( e.cancel )
					continue;
			}
			emitEvent(e);
			if ( e.kind == ERelease && pushList.length > 0 ) {
				for( i in pushList ) {
					// relX/relY is not correct here
					if( i != null )
						i.handleEvent(e);
				}
				pushList = new Array();
			}
		}
		if( hasEvents() )
			pendingEvents = new Array();
	}

	public function cleanPushList() {
		pushList = new Array();
	}

	public function addEventListener( f : hxd.Event -> Void ) {
		eventListeners.push(f);
	}

	public function removeEventListener( f : hxd.Event -> Void ) {
		return eventListeners.remove(f);
	}

	public function startDrag( f : hxd.Event -> Void, ?onCancel : Void -> Void, ?refEvent : hxd.Event ) {
		if( currentDrag != null && currentDrag.onCancel != null )
			currentDrag.onCancel();
		currentDrag = { f : f, ref : refEvent == null ? null : refEvent.touchId, onCancel : onCancel };
	}

	public function stopDrag() {
		currentDrag = null;
	}

	public function getFocus() {
		return currentFocus;
	}

	@:allow(h2d)
	function addEventTarget(i:Interactive) {
		if ( interactive.indexOf(i)>=0) return;

		// sort by which is over the other in the scene hierarchy
		inline function getLevel(i:Sprite) {
			var lv = 0;
			while( i != null ) {
				i = i.parent;
				lv++;
			}
			return lv;
		}
		inline function indexOf(p:Sprite, i:Sprite) {
			var id = -1;
			for( k in 0...p.childs.length )
				if( p.childs[k] == i ) {
					id = k;
					break;
				}
			return id;
		}
		var level = getLevel(i);
		for( index in 0...interactive.length ) {
			var i1 : Sprite = i;
			var i2 : Sprite = interactive[index];
			var lv1 = level;
			var lv2 = getLevel(i2);
			var p1 : Sprite = i1;
			var p2 : Sprite = i2;
			while( lv1 > lv2 ) {
				i1 = p1;
				p1 = p1.parent;
				lv1--;
			}
			while( lv2 > lv1 ) {
				i2 = p2;
				p2 = p2.parent;
				lv2--;
			}
			while( p1 != p2 ) {
				i1 = p1;
				p1 = p1.parent;
				i2 = p2;
				p2 = p2.parent;
			}
			if( indexOf(p1,i1) > indexOf(p2,i2) ) {
				interactive.insert(index, i);
				return;
			}
		}
		interactive.push(i);
	}

	@:allow(h2d)
	function removeEventTarget(i) {
		interactive.remove(i);
	}

}
