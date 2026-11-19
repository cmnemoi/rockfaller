package progress;

/**
 * How far the player went: the highest level they can play, their best score
 * on each level they won, the tutorials they saw, and their inventory.
 * Immutable: each change returns a new Progress.
 * Same rule as Motion-Twin's mobile server (MobileServer.SAVE_GAME).
 */
class Progress {
	static inline var FIRST_LEVEL = 1;

	public var unlockedLevel(default, null):Int;
	var bestScores:Map<Int, Int>;
	var tutorialsSeen:Array<Int>;
	public var inventory(default, null):Inventory;

	public function new(unlockedLevel:Int, bestScores:Map<Int, Int>, tutorialsSeen:Array<Int>, inventory:Inventory) {
		this.unlockedLevel = unlockedLevel;
		this.bestScores = bestScores;
		this.tutorialsSeen = tutorialsSeen;
		this.inventory = inventory;
	}

	public static function newGame():Progress {
		return new Progress(FIRST_LEVEL, new Map(), [], Inventory.starting());
	}

	public function withInventory(inventory:Inventory):Progress {
		return new Progress(unlockedLevel, bestScores, tutorialsSeen, inventory);
	}

	/** Defeats and give-ups change nothing, so only victories are recorded. */
	public function recordVictory(level:Int, score:Int, lastLevel:Int):Progress {
		if (!hasUnlocked(level))
			return this;
		var scores = copyOfBestScores();
		var bestScore = scores.get(level);
		if (bestScore == null || score > bestScore)
			scores.set(level, score);
		var winsTheLatestLevel = level == unlockedLevel && level < lastLevel;
		return new Progress(winsTheLatestLevel ? unlockedLevel + 1 : unlockedLevel, scores, tutorialsSeen, inventory);
	}

	/** Tutorials are numbered by the level that shows them (TutoManager). */
	public function markTutorialSeen(tutorial:Int):Progress {
		if (hasSeenTutorial(tutorial))
			return this;
		var seen = tutorialsSeen.concat([tutorial]);
		seen.sort(Reflect.compare);
		return new Progress(unlockedLevel, bestScores, seen, inventory);
	}

	public function hasUnlocked(level:Int):Bool {
		return level <= unlockedLevel;
	}

	public function hasSeenTutorial(tutorial:Int):Bool {
		return tutorialsSeen.indexOf(tutorial) >= 0;
	}

	public function seenTutorials():Array<Int> {
		return tutorialsSeen.copy();
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
