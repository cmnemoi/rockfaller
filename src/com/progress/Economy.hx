package progress;

/**
 * How lives and gold are spent. The offline server asks it on each game launch
 * and purchase. Today's rule is UnlimitedEconomy; Motion-Twin's lives refilling
 * every 30 minutes and gold bought with money would be another implementation,
 * keeping its state in Progress.
 */
interface Economy {
	function livesLeft(progress:Progress):Int;

	function goldLeft(progress:Progress):Int;

	function spendLife(progress:Progress):Progress;

	function spendGold(progress:Progress, price:Int):Progress;
}
