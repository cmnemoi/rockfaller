package progress;

/**
 * The saved form of a Progress, shared by every store:
 * {"version": 1, "unlockedLevel": 3, "bestScores": {"1": 4800, "2": 10875}, "tutorialsSeen": [1, 2]}.
 * plus "inventory": {"pickaxes": 1, "loots": {"fossilFish": 2}}.
 * tutorialsSeen and inventory came after the first saves: when missing, no
 * tutorial was seen and the inventory is the starting one.
 * Saved data comes from outside the game: anything unreadable gives a new game.
 */
class ProgressJson {
	static inline var VERSION = 1;

	public static function encode(progress:Progress):String {
		var bestScores = {};
		for (level in progress.wonLevels())
			Reflect.setField(bestScores, Std.string(level), progress.bestScore(level));
		return haxe.Json.stringify({
			version: VERSION,
			unlockedLevel: progress.unlockedLevel,
			bestScores: bestScores,
			tutorialsSeen: progress.seenTutorials(),
			inventory: encodeInventory(progress.inventory)
		});
	}

	public static function decode(saved:Null<String>):Progress {
		try {
			var record:Dynamic = haxe.Json.parse(saved);
			if (record.version != VERSION || !isPositiveInt(record.unlockedLevel))
				return Progress.newGame();
			var bestScores = new Map<Int, Int>();
			for (level in Reflect.fields(record.bestScores)) {
				var score:Dynamic = Reflect.field(record.bestScores, level);
				if (Std.parseInt(level) != null && Std.is(score, Int))
					bestScores.set(Std.parseInt(level), score);
			}
			var progress = new Progress(record.unlockedLevel, bestScores, [], decodeInventory(record.inventory));
			var tutorialsSeen:Array<Dynamic> = Std.is(record.tutorialsSeen, Array) ? record.tutorialsSeen : [];
			for (tutorial in tutorialsSeen)
				if (Std.is(tutorial, Int))
					progress = progress.markTutorialSeen(tutorial);
			return progress;
		} catch (unreadable:Dynamic) {
			return Progress.newGame();
		}
	}

	static function encodeInventory(inventory:Inventory):Dynamic {
		var loots = {};
		for (loot in inventory.collectedLoots())
			Reflect.setField(loots, loot.id, loot.num);
		return {pickaxes: inventory.pickaxes, loots: loots};
	}

	static function decodeInventory(record:Dynamic):Inventory {
		if (record == null || !Std.is(record.pickaxes, Int) || record.pickaxes < 0)
			return Inventory.starting();
		var loots = new Map<String, Int>();
		for (kind in Reflect.fields(record.loots)) {
			var count:Dynamic = Reflect.field(record.loots, kind);
			if (Std.is(count, Int) && count > 0)
				loots.set(kind, count);
		}
		return new Inventory(record.pickaxes, loots);
	}

	static function isPositiveInt(value:Dynamic):Bool {
		return Std.is(value, Int) && value >= 1;
	}
}
