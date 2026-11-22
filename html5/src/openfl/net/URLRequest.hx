package openfl.net;

/** openfl.net.URLRequest, as far as the game uses it: an address to open. */
class URLRequest {
	public var url:String;

	public function new(?url:String) {
		this.url = url;
	}
}
