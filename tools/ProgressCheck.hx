package tools;

import Common;
import Protocol;
import progress.InMemoryProgressStore;
import progress.Inventory;
import progress.UnlimitedEconomy;
import progress.Progress;
import progress.ProgressJson;

/**
 * Checks the player's progress: unlocking levels, keeping best scores, and saving
 * them through the offline server.
 * Run: haxe -cp . -cp src/com -D version2_1 -resource data/levels.json@levels -main tools.ProgressCheck --interp
 */
class ProgressCheck {
	static inline var LAST_LEVEL = 180;

	static function main() {
		aNewGameUnlocksOnlyLevel1();
		winningTheLastUnlockedLevelUnlocksTheNextOne();
		winningAnOlderLevelKeepsTheUnlockedLevel();
		aVictoryKeepsTheBestScore();
		aLevelNotYetUnlockedCannotBeRecorded();
		winningTheLastLevelUnlocksNothingBeyondIt();
		progressSurvivesAJsonRoundTrip();
		unreadableSavedProgressStartsANewGame();
		theOfflineServerSavesVictoriesAndServesThemBack();
		theOfflineServerIgnoresDefeats();
		aNewGameHasSeenNoTutorial();
		aSeenTutorialIsRemembered();
		seenTutorialsSurviveAJsonRoundTrip();
		aSaveWithoutTutorialsHasSeenNone();
		theOfflineServerSavesSeenTutorials();
		winningLevels1To3MarksTheirTutorialsSeen();
		losingLevel1LeavesItsTutorialToSee();
		aNewGameSkipsTheTutorialsNotCheckedOnExtractedLevels();
		aNewGameHasOnePickaxeAndNoLoot();
		usingAPickaxeRemovesOneButNeverGoesBelowZero();
		lootIsCollectedByKind();
		theInventorySurvivesAJsonRoundTrip();
		aSaveWithoutInventoryStartsWithTheStartingOne();
		theOfflineServerSavesPickaxesUsedAndBought();
		theOfflineServerCollectsLootFromEveryGameOnUnlockedLevels();
		theUnlimitedEconomyNeverRunsOut();
		theOfflineServerSpendsLivesAndGoldThroughTheEconomy();
		trace("PASS");
	}

	static function aNewGameUnlocksOnlyLevel1() {
		var progress = Progress.newGame();

		check(progress.unlockedLevel == 1, "a new game unlocks level 1 only");
		check(progress.bestScore(1) == null, "a new game has no best score");
	}

	static function winningTheLastUnlockedLevelUnlocksTheNextOne() {
		var progress = Progress.newGame().recordVictory(1, 4800, LAST_LEVEL);

		check(progress.unlockedLevel == 2, "winning level 1 unlocks level 2");
		check(progress.bestScore(1) == 4800, "winning level 1 records its score");
	}

	static function winningAnOlderLevelKeepsTheUnlockedLevel() {
		var progress = Progress.newGame().recordVictory(1, 4800, LAST_LEVEL).recordVictory(1, 5000, LAST_LEVEL);

		check(progress.unlockedLevel == 2, "winning level 1 again does not unlock level 3");
	}

	static function aVictoryKeepsTheBestScore() {
		var progress = Progress.newGame().recordVictory(1, 4800, LAST_LEVEL);

		check(progress.recordVictory(1, 5000, LAST_LEVEL).bestScore(1) == 5000, "a higher score replaces the best score");
		check(progress.recordVictory(1, 3000, LAST_LEVEL).bestScore(1) == 4800, "a lower score keeps the best score");
	}

	static function aLevelNotYetUnlockedCannotBeRecorded() {
		var progress = Progress.newGame().recordVictory(5, 9000, LAST_LEVEL);

		check(progress.unlockedLevel == 1, "winning a locked level unlocks nothing");
		check(progress.bestScore(5) == null, "winning a locked level records no score");
	}

	static function winningTheLastLevelUnlocksNothingBeyondIt() {
		var progress = Progress.newGame();
		for (level in 1...4)
			progress = progress.recordVictory(level, 1000, 3);

		check(progress.unlockedLevel == 3, "the last level stays the last unlocked level");
		check(progress.bestScore(3) == 1000, "winning the last level records its score");
	}

	static function progressSurvivesAJsonRoundTrip() {
		var progress = Progress.newGame().recordVictory(1, 4800, LAST_LEVEL).recordVictory(2, 10875, LAST_LEVEL);

		var restored = ProgressJson.decode(ProgressJson.encode(progress));

		check(restored.unlockedLevel == 3, "the unlocked level survives JSON");
		check(restored.bestScore(1) == 4800 && restored.bestScore(2) == 10875, "best scores survive JSON");
	}

	static function unreadableSavedProgressStartsANewGame() {
		for (saved in [null, "", "not json", '{"version":1}', '{"version":99,"unlockedLevel":7,"bestScores":{}}'])
			check(ProgressJson.decode(saved).unlockedLevel == 1, "unreadable progress starts a new game: " + saved);
	}

	static function theOfflineServerSavesVictoriesAndServesThemBack() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		Protocol.offlineResponse(ProtocolCom.DoSendGame(game(1, TypeEndGame.TEGVictory, 4800)));

		check(store.load().unlockedLevel == 2, "the server saves the unlocked level");
		var userData = initUserData();
		check(userData.levelMax == 2, "the server serves the saved unlocked level");
		check(userData.arHighScore[1] == 4800, "the server serves the saved best score");
	}

	static function theOfflineServerIgnoresDefeats() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		Protocol.offlineResponse(ProtocolCom.DoSendGame(game(1, TypeEndGame.TEGDefeat, 800)));

		check(store.load().unlockedLevel == 1, "a defeat unlocks nothing");
		check(initUserData().arHighScore[1] == null, "a defeat records no score");
	}

	static function aNewGameHasSeenNoTutorial() {
		check(!Progress.newGame().hasSeenTutorial(1), "a new game has seen no tutorial");
	}

	static function aSeenTutorialIsRemembered() {
		var progress = Progress.newGame().markTutorialSeen(4).markTutorialSeen(4);

		check(progress.hasSeenTutorial(4), "a seen tutorial is remembered");
		check(!progress.hasSeenTutorial(5), "other tutorials stay to see");
		check(progress.seenTutorials().length == 1, "a tutorial seen twice counts once");
	}

	static function seenTutorialsSurviveAJsonRoundTrip() {
		var progress = Progress.newGame().markTutorialSeen(4).markTutorialSeen(12);

		var restored = ProgressJson.decode(ProgressJson.encode(progress));

		check(restored.hasSeenTutorial(4) && restored.hasSeenTutorial(12), "seen tutorials survive JSON");
	}

	static function aSaveWithoutTutorialsHasSeenNone() {
		var progress = ProgressJson.decode('{"version":1,"unlockedLevel":2,"bestScores":{"1":6525}}');

		check(progress.unlockedLevel == 2, "a save from before tutorials keeps its levels");
		check(progress.seenTutorials().length == 0, "a save from before tutorials has seen none");
	}

	static function theOfflineServerSavesSeenTutorials() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		var response = Protocol.offlineResponse(ProtocolCom.DoUpdateTuto(4));

		check(store.load().hasSeenTutorial(4), "the server saves a seen tutorial");
		check(initUserData().tutoDone.indexOf(4) >= 0, "the server serves seen tutorials");
		switch (response) {
			case ProtocolCom.SendUserData(userData):
				check(userData.tutoDone.indexOf(4) >= 0, "the server answers with the updated tutorials at once");
			default:
				throw "FAILED: the server answers a seen tutorial with the player's data";
		}
	}

	static function winningLevels1To3MarksTheirTutorialsSeen() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		for (level in 1...5)
			Protocol.offlineResponse(ProtocolCom.DoSendGame(game(level, TypeEndGame.TEGVictory, 1000)));

		check(store.load().seenTutorials().join(",") == "1,2,3", "winning levels 1 to 3 marks only their tutorials seen");
	}

	static function losingLevel1LeavesItsTutorialToSee() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		Protocol.offlineResponse(ProtocolCom.DoSendGame(game(1, TypeEndGame.TEGDefeat, 800)));

		check(initUserData().tutoDone.indexOf(1) < 0, "losing level 1 leaves its tutorial to see");
	}

	/** Tutorials 2 and 3 point at cells of Motion-Twin's layouts, which extracted levels lack. */
	static function aNewGameSkipsTheTutorialsNotCheckedOnExtractedLevels() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		var tutorialsDone = initUserData().tutoDone;

		check(tutorialsDone.indexOf(1) < 0, "the level 1 tutorial, checked, shows in a new game");
		check(tutorialsDone.indexOf(2) >= 0 && tutorialsDone.indexOf(3) >= 0, "the level 2 and 3 tutorials are skipped");
		check(store.load().seenTutorials().length == 0, "skipped tutorials are not saved as seen");
	}

	static function aNewGameHasOnePickaxeAndNoLoot() {
		var inventory = Progress.newGame().inventory;

		check(inventory.pickaxes == 1, "a new game has one pickaxe");
		check(inventory.collectedLoots().length == 0, "a new game has no loot");
	}

	static function usingAPickaxeRemovesOneButNeverGoesBelowZero() {
		var inventory = Inventory.starting().usePickaxe();

		check(inventory.pickaxes == 0, "using a pickaxe removes one");
		check(inventory.usePickaxe().pickaxes == 0, "pickaxes never go below zero");
		check(inventory.addPickaxes(5).pickaxes == 5, "bought pickaxes are added");
	}

	static function lootIsCollectedByKind() {
		var inventory = Inventory.starting()
			.collectLoots([{id: "fossilFish", num: 1}, {id: "gearPump", num: 2}])
			.collectLoots([{id: "fossilFish", num: 3}]);

		check(inventory.lootCount("fossilFish") == 4, "loot of the same kind adds up");
		check(inventory.lootCount("gearPump") == 2, "each kind of loot is counted");
		check(inventory.lootCount("dragonEgg") == 0, "loot never found counts zero");
	}

	static function theInventorySurvivesAJsonRoundTrip() {
		var inventory = Inventory.starting().addPickaxes(5).collectLoots([{id: "fossilFish", num: 2}]);
		var progress = Progress.newGame().withInventory(inventory);

		var restored = ProgressJson.decode(ProgressJson.encode(progress)).inventory;

		check(restored.pickaxes == 6, "pickaxes survive JSON");
		check(restored.lootCount("fossilFish") == 2, "loot survives JSON");
	}

	static function aSaveWithoutInventoryStartsWithTheStartingOne() {
		var inventory = ProgressJson.decode('{"version":1,"unlockedLevel":2,"bestScores":{}}').inventory;

		check(inventory.pickaxes == 1 && inventory.collectedLoots().length == 0, "a save from before the inventory gets the starting one");
	}

	static function theOfflineServerSavesPickaxesUsedAndBought() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		Protocol.offlineResponse(ProtocolCom.DoUsePickaxe);
		check(store.load().inventory.pickaxes == 0, "the server saves a used pickaxe");
		check(Type.enumEq(Protocol.offlineResponse(ProtocolCom.DoCheckPickaxe), ProtocolCom.SendUsePickaxe(false)), "no pickaxe left to use");

		switch (Protocol.offlineResponse(ProtocolCom.DoBuyPickaxes(false))) {
			case ProtocolCom.SendValidPurchasePickaxe(userData):
				check(userData.pickaxe == 5, "the server answers a purchase with the new pickaxes");
			default:
				throw "FAILED: the server validates a pickaxe purchase";
		}
		check(store.load().inventory.pickaxes == 5, "the server saves bought pickaxes");
		check(initUserData().pickaxe == 5, "the server serves saved pickaxes");
	}

	static function theOfflineServerCollectsLootFromEveryGameOnUnlockedLevels() {
		var store = new InMemoryProgressStore();
		Protocol.useProgressStore(store);

		Protocol.offlineResponse(ProtocolCom.DoSendGame(gameWithLoot(1, TypeEndGame.TEGVictory, "fossilFish")));
		Protocol.offlineResponse(ProtocolCom.DoSendGame(gameWithLoot(1, TypeEndGame.TEGDefeat, "fossilFish")));
		Protocol.offlineResponse(ProtocolCom.DoSendGame(gameWithLoot(9, TypeEndGame.TEGVictory, "gearPump")));

		var loots = initUserData().arLoots;
		check(loots.length == 1 && loots[0].id == "fossilFish" && loots[0].num == 2, "loot from games on unlocked levels is collected");
	}

	static function theUnlimitedEconomyNeverRunsOut() {
		var economy = new UnlimitedEconomy();
		var progress = economy.spendGold(economy.spendLife(Progress.newGame()), Protocol.PRICE_5_LIFES);

		check(economy.livesLeft(progress) == Protocol.MAX_LIFES, "lives are unlimited");
		check(economy.goldLeft(progress) == 10000, "gold is unlimited");
	}

	static function theOfflineServerSpendsLivesAndGoldThroughTheEconomy() {
		Protocol.useProgressStore(new InMemoryProgressStore());

		Protocol.offlineResponse(ProtocolCom.DoLaunchGame(1));
		Protocol.offlineResponse(ProtocolCom.DoBuyMoves(false));

		var userData = initUserData();
		check(userData.life == Protocol.MAX_LIFES && userData.gold == 10000, "the server serves the economy's lives and gold");
	}

	static function gameWithLoot(level:Int, success:TypeEndGame, loot:String):GameData {
		var played = game(level, success, 1000);
		played.arLoots = [{id: loot, num: 1}];
		return played;
	}

	static function game(level:Int, success:TypeEndGame, score:Int):GameData {
		return {
			mobileID: null, level: level, version: 1, date: null,
			success: success, score: score,
			boosterUsed: 0, addMovesUsed: 0, movesUsed: 1,
			arAssets: [], arLoots: []
		};
	}

	static function initUserData():UserData {
		switch (Protocol.offlineResponse(ProtocolCom.DoGetInitData(null, LAST_LEVEL))) {
			case ProtocolCom.SendInitData(initData):
				return initData.userData;
			default:
				throw "offline bootstrap did not return init data";
		}
	}

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}
