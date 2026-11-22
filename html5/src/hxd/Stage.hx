package hxd;

/** Replaces the fork's platform Stage: where the mouse is, in screen pixels. */
class Stage {
	static var instance:Stage;

	public var mouseX(default, null):Float = 0;
	public var mouseY(default, null):Float = 0;

	function new() {}

	public static function getInstance():Stage {
		if (instance == null) instance = new Stage();
		return instance;
	}
}
