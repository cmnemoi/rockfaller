package progress;

/**
 * Saves the progress in the browser's localStorage, as the JSON ProgressJson writes: the same string the Flash
 * build keeps in its SharedObject. Storage can be blocked or full: like the Flash store, the game then goes on without saving.
 * @spec html5.boot::progress-in-local-storage
 */
class LocalStorageProgressStore implements ProgressStore {
	static inline var KEY = "rockfaller.progress";

	/** Anything with localStorage's getItem and setItem. */
	var storage:Dynamic;

	public function new(?storage:Dynamic) {
		this.storage = storage;
	}

	public function load():Progress {
		try {
			return ProgressJson.decode(localStorage().getItem(KEY));
		} catch (storageUnavailable:Dynamic) {
			trace("progress not loaded: " + storageUnavailable);
			return Progress.newGame();
		}
	}

	public function save(progress:Progress):Void {
		try {
			localStorage().setItem(KEY, ProgressJson.encode(progress));
		} catch (storageUnavailable:Dynamic) {
			trace("progress not saved: " + storageUnavailable);
		}
	}

	function localStorage():Dynamic {
		#if js
		if (storage == null)
			storage = js.Browser.window.localStorage;
		#end
		return storage;
	}
}
