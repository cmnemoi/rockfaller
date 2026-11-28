package hxd;

import haxe.PosInfos;

enum Cursor {
	Default;
	Button;
	Move;
	TextInput;
	Hide;
}

/** Replaces the fork's platform System: the screen size, the mouse cursor, and the debug traces BLib calls. */
class System {
	public static var width(default, null):Int = 640;
	public static var height(default, null):Int = 768;
	public static var debugLevel = 0;
	/** The cursor in effect, as an Interactive set it. */
	public static var cursor(default, null):Cursor = Default;

	public inline static function trace2(msg:Dynamic, ?pos:PosInfos) {
		#if debug
		if (debugLevel >= 2) trace(pos.fileName + ":" + pos.methodName + ":" + pos.lineNumber + " " + msg);
		#end
		return msg;
	}

	#if js
	static var loop:Void->Void;
	static var looping = false;

	/** Like the fork's Flash ENTER_FRAME loop: f runs once per screen frame (requestAnimationFrame), until replaced or set to null. */
	public static function setLoop(f:Void->Void) {
		loop = f;
		if (f != null && !looping) {
			looping = true;
			js.Browser.window.requestAnimationFrame(runLoop);
		}
	}

	static function runLoop(_) {
		if (loop == null) {
			looping = false;
			return;
		}
		// @spec html5.h2d::loop-survives-errors: asked first, so a frame that throws does not stop the game, like Flash's ENTER_FRAME.
		js.Browser.window.requestAnimationFrame(runLoop);
		loop();
	}
	#end

	public static function setCursor(c:Cursor) {
		cursor = c;
		#if js
		var canvas = Stage.getInstance().canvas;
		if (canvas != null)
			canvas.style.cursor = switch (c) {
				case Default: "default";
				case Button: "pointer";
				case Move: "move";
				case TextInput: "text";
				case Hide: "none";
			};
		#end
	}
}
