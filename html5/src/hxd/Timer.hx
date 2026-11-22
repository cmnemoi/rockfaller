package hxd;

/**
 * The fork's hxd.Timer. Only wantedFPS changes: the fork reads the Flash stage's frame rate,
 * which is the game's 30 frames per second (Application.xml, <window fps="30">).
 */
class Timer {

	public static inline var GAME_FPS = 30;

	public static function wantedFPS() {
		return GAME_FPS;
	}
	
	public static var maxDeltaTime = 0.5;
	public static var oldTime = haxe.Timer.stamp();
	public static var tmod_factor = 0.95;
	public static var calc_tmod : Float = 1;
	public static var tmod : Float = 1.0;
	public static var deltaT : Float = 1;
	public static var rdeltaT : Float = 1;
	static var frameCount = 0;

	public inline static function update() {
		frameCount++;
		var newTime = haxe.Timer.stamp();
		rdeltaT = deltaT = newTime - oldTime;
		if ( deltaT == 0.0 ) rdeltaT = deltaT = hxd.Math.EPSILON;
		
		oldTime = newTime;
		if( deltaT < maxDeltaTime )
			calc_tmod = calc_tmod * tmod_factor + (1 - tmod_factor) * deltaT * wantedFPS();
		else
			deltaT = 1 / wantedFPS();
		tmod = calc_tmod;
	}

	public inline static function fps() : Float {
		return wantedFPS()/tmod ;
	}
	
	public static function skip() {
		oldTime = haxe.Timer.stamp();
	}

}
