package tools;

import Common;
import Protocol;
import progress.InMemoryProgressStore;
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
