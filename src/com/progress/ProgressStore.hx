package progress;

/**
 * Where the player's progress is kept between sessions. Adapters: in memory,
 * the Flash SharedObject (the browser's localStorage under Ruffle), and later
 * IndexedDB or a remote server such as Eternaltwin.
 */
interface ProgressStore {
	/** The saved progress, or a new game when nothing readable is saved. */
	function load():Progress;

	function save(progress:Progress):Void;
}
