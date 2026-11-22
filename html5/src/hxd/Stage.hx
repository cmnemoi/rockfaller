package hxd;

/**
 * Replaces the fork's platform Stage: the screen's size, where the pointer is, and who hears its events.
 * In the browser, attachTo() turns the canvas's pointer events (mouse and touch alike) into hxd.Events,
 * in game pixels even when the page shows the canvas at another size.
 */
class Stage {
	static var instance:Stage;

	public var width(default, null):Int;
	public var height(default, null):Int;
	public var mouseX(default, null):Float = 0;
	public var mouseY(default, null):Float = 0;
	#if js
	public var canvas(default, null):js.html.CanvasElement;
	#end

	var eventTargets:Array<Event->Void> = [];

	function new() {
		width = System.width;
		height = System.height;
	}

	/** The Flash stage's frame rate: the game runs at 30 frames per second. */
	public function getFrameRate():Float {
		return Timer.GAME_FPS;
	}

	public static function getInstance():Stage {
		if (instance == null) instance = new Stage();
		return instance;
	}

	public function addEventTarget(target:Event->Void) {
		eventTargets.push(target);
	}

	public function removeEventTarget(target:Event->Void) {
		eventTargets.remove(target);
	}

	/** Moves the pointer there and tells every target, like the fork's Stage does for Flash mouse events. */
	public function event(e:Event) {
		mouseX = e.relX;
		mouseY = e.relY;
		for (target in eventTargets.copy())
			target(e);
	}

	#if js
	public function attachTo(canvas:js.html.CanvasElement) {
		this.canvas = canvas;
		canvas.style.touchAction = "none"; // a touch drag must not scroll the page
		canvas.addEventListener("pointerdown", function(e:js.html.PointerEvent) {
			canvas.setPointerCapture(e.pointerId); // keeps the release even when it happens outside the canvas
			fromPointer(EPush, e);
		});
		canvas.addEventListener("pointerup", function(e:js.html.PointerEvent) fromPointer(ERelease, e));
		canvas.addEventListener("pointermove", function(e:js.html.PointerEvent) fromPointer(EMove, e));
	}

	function fromPointer(kind:Event.EventKind, e:js.html.PointerEvent) {
		var box = canvas.getBoundingClientRect();
		var gameEvent = new Event(kind, (e.clientX - box.left) * width / box.width, (e.clientY - box.top) * height / box.height);
		gameEvent.button = e.button < 0 ? 0 : e.button;
		gameEvent.touchId = e.pointerId;
		event(gameEvent);
	}
	#end
}
