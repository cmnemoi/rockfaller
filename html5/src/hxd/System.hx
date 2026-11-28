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
	// Flash called ENTER_FRAME at the stage's rate: the game's 30 frames per second.
	static inline var STAGE_FRAME_MS = 1000 / hxd.Timer.GAME_FPS;
	// Animation frame times drift by a millisecond or so: well under a 120 Hz screen's frame (8.3 ms).
	static inline var FRAME_TIME_TOLERANCE_MS = 4;

	static var loop:Void->Void;
	static var looping = false;
	static var lastCallMs:Null<Float> = null;

	/**
	 * Like the fork's Flash ENTER_FRAME loop: f runs 30 times per second, until replaced or set to null.
	 * @spec html5.h2d::loop-at-stage-rate: the game moves 30 steps per second; drawing every screen frame of a
	 * 60 or 120 Hz screen would draw the same picture 2 or 4 times. A screen slower than 30 Hz runs f every frame.
	 */
	public static function setLoop(f:Void->Void) {
		loop = f;
		if (f != null && !looping) {
			looping = true;
			lastCallMs = null;
			js.Browser.window.requestAnimationFrame(runLoop);
		}
	}

	static function runLoop(timeMs:Float) {
		if (loop == null) {
			looping = false;
			return;
		}
		// @spec html5.h2d::loop-survives-errors: asked first, so a frame that throws does not stop the game, like Flash's ENTER_FRAME.
		js.Browser.window.requestAnimationFrame(runLoop);
		if (isBeforeNextStageFrame(timeMs))
			return;
		lastCallMs = timeMs;
		loop();
	}

	static function isBeforeNextStageFrame(timeMs:Float):Bool {
		return lastCallMs != null && timeMs - lastCallMs < STAGE_FRAME_MS - FRAME_TIME_TOLERANCE_MS;
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
