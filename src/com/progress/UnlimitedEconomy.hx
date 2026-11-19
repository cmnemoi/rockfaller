package progress;

/** Lives and gold never run out: nothing is spent. */
class UnlimitedEconomy implements Economy {
	static inline var GOLD = 10000;

	public function new() {}

	public function livesLeft(progress:Progress):Int {
		return Protocol.MAX_LIFES;
	}

	public function goldLeft(progress:Progress):Int {
		return GOLD;
	}

	public function spendLife(progress:Progress):Progress {
		return progress;
	}

	public function spendGold(progress:Progress, price:Int):Progress {
		return progress;
	}
}
