package progress;

/**
 * What the player owns: pickaxes and the loot found in games, counted by kind.
 * Immutable: each change returns a new Inventory.
 */
class Inventory {
	static inline var STARTING_PICKAXES = 1;

	public var pickaxes(default, null):Int;
	var loots:Map<String, Int>;

	public function new(pickaxes:Int, loots:Map<String, Int>) {
		this.pickaxes = pickaxes;
		this.loots = loots;
	}

	public static function starting():Inventory {
		return new Inventory(STARTING_PICKAXES, new Map());
	}

	public function usePickaxe():Inventory {
		return new Inventory(pickaxes > 0 ? pickaxes - 1 : 0, loots);
	}

	public function addPickaxes(count:Int):Inventory {
		return new Inventory(pickaxes + count, loots);
	}

	public function collectLoots(found:Array<{id:String, num:Int}>):Inventory {
		var collected = new Map<String, Int>();
		for (kind in loots.keys())
			collected.set(kind, loots.get(kind));
		for (loot in found)
			collected.set(loot.id, lootCount(loot.id) + loot.num);
		return new Inventory(pickaxes, collected);
	}

	public function lootCount(kind:String):Int {
		return loots.exists(kind) ? loots.get(kind) : 0;
	}

	/** In the shape UserData.arLoots expects. */
	public function collectedLoots():Array<{id:String, num:Int}> {
		return [for (kind in loots.keys()) {id: kind, num: loots.get(kind)}];
	}
}
