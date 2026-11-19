package progress;

/**
 * How far the player went: the highest level they can play, and their best score
 * on each level they won. Immutable: recording a victory returns a new Progress.
 * Same rule as Motion-Twin's mobile server (MobileServer.SAVE_GAME).
 */
class Progress {
	static inline var FIRST_LEVEL = 1;

	public var unlockedLevel(default, null):Int;
	var bestScores:Map<Int, Int>;

	public function new(unlockedLevel:Int, bestScores:Map<Int, Int>) {
		this.unlockedLevel = unlockedLevel;
		this.bestScores = bestScores;
	}

	public static function newGame():Progress {
		return new Progress(FIRST_LEVEL, new Map());
	}

	/** Defeats and give-ups change nothing, so only victories are recorded. */
	public function recordVictory(level:Int, score:Int, lastLevel:Int):Progress {
		if (level > unlockedLevel)
			return this;
		var scores = copyOfBestScores();
		var bestScore = scores.get(level);
		if (bestScore == null || score > bestScore)
			scores.set(level, score);
		var winsTheLatestLevel = level == unlockedLevel && level < lastLevel;
		return new Progress(winsTheLatestLevel ? unlockedLevel + 1 : unlockedLevel, scores);
	}

	public function bestScore(level:Int):Null<Int> {
		return bestScores.get(level);
	}

	public function wonLevels():Iterator<Int> {
		return bestScores.keys();
	}

	function copyOfBestScores():Map<Int, Int> {
		var copy = new Map<Int, Int>();
		for (level in bestScores.keys())
			copy.set(level, bestScores.get(level));
		return copy;
	}
}
