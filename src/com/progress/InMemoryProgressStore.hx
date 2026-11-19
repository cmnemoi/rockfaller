package progress;

/** Keeps the progress for the current session only. */
class InMemoryProgressStore implements ProgressStore {
	var progress:Progress;

	public function new() {
		progress = Progress.newGame();
	}

	public function load():Progress {
		return progress;
	}

	public function save(progress:Progress):Void {
		this.progress = progress;
	}
}
