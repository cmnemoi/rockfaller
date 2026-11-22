package hxd;

import haxe.PosInfos;

/** Replaces the fork's platform System: the screen size, and the debug traces BLib calls. */
class System {
	public static var width(default, null):Int = 640;
	public static var height(default, null):Int = 768;
	public static var debugLevel = 0;

	public inline static function trace2(msg:Dynamic, ?pos:PosInfos) {
		#if debug
		if (debugLevel >= 2) trace(pos.fileName + ":" + pos.methodName + ":" + pos.lineNumber + " " + msg);
		#end
		return msg;
	}
}
