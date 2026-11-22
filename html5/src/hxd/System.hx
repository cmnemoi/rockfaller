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
