package tools;

import Protocol;
import Common;

/**
 * Checks the offline server on the levels extracted from the playthrough.
 * Run: haxe -cp . -cp src/com -D version2_1 -resource data/levels.json@levels -main tools.ProtocolCheck --interp
 */
class ProtocolCheck {
	static function main() {
		var levels = initLevels();
		check(levels.length == 180, "the offline server serves the 180 extracted levels");

		var level1 = levels[0];
		check(level1.level == 1 && level1.numMoves == 6, "level 1 ends after its 6 tutorial moves");
		check(Type.enumEq(level1.type, TypeGoal.TGScoring(5000)), "level 1 asks for 5000 points");
		check(Type.enumEq(level1.biome, TypeBiome.TBClassic), "level 1 is in the classic biome");

		for (level in levels)
			check(Common.VALIDATE_LEVEL(level), "level " + level.level + " passes the game's validation");

		var level88 = levels[87];
		check(hasManualRock(level88, 4, 0, TypeRock.TRBombCiv(7)), "level 88 has a time bomb at 7 on top of column 4");
		check(level88.arStepScore.join(",") == "30000,40000,50000", "level 88 star thresholds");

		var end = Protocol.offlineResponse(ProtocolCom.DoSendGame({
			mobileID: null, level: 1, version: 1, date: null,
			success: TypeEndGame.TEGVictory, score: 1000,
			boosterUsed: 0, addMovesUsed: 0, movesUsed: 1,
			arAssets: [], arLoots: []
		}));
		switch (end) {
			case ProtocolCom.SendValidEndGame(userData, _):
				check(userData.levelMax == 2, "winning level 1 unlocks level 2");
			default:
				throw "offline end game did not return validation";
		}
	}

	static function initLevels():Array<LevelInfo> {
		switch (Protocol.offlineResponse(ProtocolCom.DoGetInitData(null, 180))) {
			case ProtocolCom.SendInitData(data):
				return data.levels;
			default:
				throw "offline bootstrap did not return init data";
		}
	}

	static function hasManualRock(level:LevelInfo, x:Int, y:Int, rock:TypeRock):Bool {
		for (manual in level.arManualRocks)
			if (manual.x == x && manual.y == y && Type.enumEq(manual.tr, rock))
				return true;
		return false;
	}

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}
