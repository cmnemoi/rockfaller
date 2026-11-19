package progress;

import flash.net.SharedObject;

/**
 * Saves the progress in a Flash SharedObject. Ruffle keeps it in the browser's
 * localStorage on the web, and in a file with the desktop player.
 * Storage can be disabled or full: the game then goes on without saving.
 */
class SharedObjectProgressStore implements ProgressStore {
	static inline var SHARED_OBJECT_NAME = "rockfaller";
	static inline var SHARED_OBJECT_PATH = "/";

	public function new() {}

	public function load():Progress {
		try {
			return ProgressJson.decode(sharedObject().data.progress);
		} catch (storageUnavailable:Dynamic) {
			trace("progress not loaded: " + storageUnavailable);
			return Progress.newGame();
		}
	}

	public function save(progress:Progress):Void {
		try {
			var shared = sharedObject();
			shared.data.progress = ProgressJson.encode(progress);
			shared.flush();
		} catch (storageUnavailable:Dynamic) {
			trace("progress not saved: " + storageUnavailable);
		}
	}

	function sharedObject():SharedObject {
		return SharedObject.getLocal(SHARED_OBJECT_NAME, SHARED_OBJECT_PATH);
	}
}
