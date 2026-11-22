package openfl;

/** openfl.Lib, as far as the game uses it in the JS build: opening a link (the soundtrack, the app stores, the home page). */
class Lib {
	public static function getURL(request:openfl.net.URLRequest, ?target:String) {
		#if js
		js.Browser.window.open(request.url, target == null ? "_blank" : target);
		#end
	}
}
