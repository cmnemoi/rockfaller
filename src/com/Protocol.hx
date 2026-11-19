package;

import Common;
import progress.Economy;
import progress.InMemoryProgressStore;
import progress.Progress;
import progress.ProgressStore;
import progress.UnlimitedEconomy;

typedef InitClient = {
	var level:Int;
	var urlImages:String;
	var urlSounds:String;
}

typedef FriendRequestResult = {
	var addLife:Null<Int>;
	var newLife:Int;
}

enum FriendRequestType {
	R_GiveLife;
	R_AskLife;
	R_InviteFriend;
}

enum ProtocolError {
	PEProtocolNotHandled(p:ProtocolCom);
	PEUserNotAdmin;
	PEUserInfoNull;
	PEUserHasNotEnoughMoney(ud:UserData);
	PEUserHasNoLife(ud:UserData);
	PEUserHasNoPickaxe;
	PELevelForbidden(level:Int, ud:UserData);
	PENotLevelToDelete(level:Int);
	PENotLevelToMove(level:Int);
}

enum ProtocolCom {
	DoGetLevelsForEditor;
	DoSaveLevel(level:LevelInfo);
	DoTestLE(level:Int);
	DoTestLevel(level:Int);
	DoDeleteLevel(level:Int);
	DoMoveLevel(oldLevel:Int, newLevel:Int);
	DoGetUserData;
	DoSendGame(gameData:GameData);
	DoLaunchGame(level:Int);
	DoUpdateMusic(enabled:Bool);
	DoUpdateSFX(enabled:Bool);
	DoUsePickaxe;
	DoBuyPickaxes(useGold:Bool);
	DoBuyMoves(useGold:Bool);
	DoBuyLifes;
	SendDataBouiller;
	DoUpdateTuto(step:Int);
	DoCheckTransaction;
	DoGetRequestsCount;
	DoGetInitData(generateMobileId:Null<Bool>, maxLevel:Int);
	DoMobileAPI(games:Array<GameData>, command:Null<ProtocolCom>);
	DoCheckPickaxe;
	DoUpdateHint(enabled:Bool);

	SendInitData(data:InitData);
	SendLevels(levels:Array<LevelInfo>);
	SendUserData(userData:UserData);
	SendRequestCount(count:Int);
	SendValidLaunchGame(userData:UserData);
	SendValidEndGame(userData:UserData, serverTime:Float);
	SendValidPurchaseMoves(userData:UserData);
	SendValidPurchasePickaxe(userData:UserData);
	SendValidPurchaseLife(userData:UserData);
	SendTransactionData(isValid:Bool, userData:UserData);
	SendUsePickaxe(canUse:Bool);
	SendValidMobileAPI(ids:Array<Int>, response:Null<ProtocolCom>);

	PCDone;
	PCError(error:ProtocolError, stack:Dynamic);
}

class Protocol {
	public static inline var MAX_LIFES:Int = 5;
	public static inline var TIME_REFILL_LIFE:Int = 30;

	public static inline var PRICE_5_MOVES:Int = 250;
	public static inline var PRICE_5_PICKAXE:Int = 400;
	public static inline var PRICE_5_LIFES:Int = 900;

	static var levels:Array<LevelInfo>;
	static var progressStore:ProgressStore = new InMemoryProgressStore();
	static var economy:Economy = new UnlimitedEconomy();
	// DoBuyPickaxes(true) is the tutorial's free pack (BoosterPickaxe).
	static inline var PICKAXES_PER_PACK = 5;
	// The client never reports the tutorials of levels 1 to 3 (TutoManager sends
	// DoUpdateTuto from level 4 on): winning those levels marks them seen.
	static var LEVELS_WITH_UNREPORTED_TUTORIAL = [1, 2, 3];
	// Tutorials not yet checked on the extracted levels: some point at cells of
	// Motion-Twin's own layouts (level 2 at 3,4 then 4,6) and block the level on
	// a random one. They are served as seen, without being saved as seen; remove
	// one from here once it works.
	static var UNVERIFIED_TUTORIALS = [2, 3, 4, 5, 6, 7, 8, 10, 12, 13, 16, 36, 56, 76, 96, 121];

	public static function init():Void {}

	/** The client plugs its persistent store at startup; tests keep one in memory. */
	public static function useProgressStore(store:ProgressStore):Void {
		progressStore = store;
	}

	public static function offlineResponse(command:Null<ProtocolCom>):ProtocolCom {
		var userData = offlineUserData();
		if (command == null)
			return ProtocolCom.PCDone;

		switch (command) {
			case ProtocolCom.DoGetInitData(_, _):
				return ProtocolCom.SendInitData({
					now: Date.now().getTime(),
					userData: userData,
					levels: offlineLevels(),
					friends: [],
					mobileId: null,
					avatar: null
				});
			case ProtocolCom.DoGetLevelsForEditor:
				return ProtocolCom.SendLevels(offlineLevels());
			case ProtocolCom.DoLaunchGame(_):
				progressStore.save(economy.spendLife(progressStore.load()));
				return ProtocolCom.SendValidLaunchGame(offlineUserData());
			case ProtocolCom.DoSendGame(gameData):
				progressStore.save(recordGame(progressStore.load(), gameData));
				userData = offlineUserData();
				return ProtocolCom.SendValidEndGame(userData, Date.now().getTime());
			case ProtocolCom.DoUpdateTuto(tutorial):
				progressStore.save(progressStore.load().markTutorialSeen(tutorial));
				return ProtocolCom.SendUserData(offlineUserData());
			case ProtocolCom.DoGetUserData:
				return ProtocolCom.SendUserData(userData);
			case ProtocolCom.DoBuyMoves(_):
				progressStore.save(economy.spendGold(progressStore.load(), PRICE_5_MOVES));
				return ProtocolCom.SendValidPurchaseMoves(offlineUserData());
			case ProtocolCom.DoBuyPickaxes(free):
				var progress = progressStore.load();
				if (!free)
					progress = economy.spendGold(progress, PRICE_5_PICKAXE);
				progressStore.save(progress.withInventory(progress.inventory.addPickaxes(PICKAXES_PER_PACK)));
				return ProtocolCom.SendValidPurchasePickaxe(offlineUserData());
			case ProtocolCom.DoBuyLifes:
				progressStore.save(economy.spendGold(progressStore.load(), PRICE_5_LIFES));
				return ProtocolCom.SendValidPurchaseLife(offlineUserData());
			case ProtocolCom.DoUsePickaxe:
				var progress = progressStore.load();
				progressStore.save(progress.withInventory(progress.inventory.usePickaxe()));
				return ProtocolCom.PCDone;
			case ProtocolCom.DoCheckPickaxe:
				return ProtocolCom.SendUsePickaxe(userData.pickaxe > 0);
			case ProtocolCom.DoMobileAPI(_, _):
				return ProtocolCom.SendValidMobileAPI([], ProtocolCom.PCDone);
			default:
				return ProtocolCom.PCDone;
		}
	}

	/** Same rule as Motion-Twin's mobile server (MobileServer.SAVE_GAME). */
	static function recordGame(progress:Progress, gameData:GameData):Progress {
		if (!progress.hasUnlocked(gameData.level))
			return progress;
		progress = progress.withInventory(progress.inventory.collectLoots(gameData.arLoots));
		if (gameData.success != TypeEndGame.TEGVictory)
			return progress;
		progress = progress.recordVictory(gameData.level, gameData.score, offlineLevels().length);
		if (LEVELS_WITH_UNREPORTED_TUTORIAL.indexOf(gameData.level) >= 0)
			progress = progress.markTutorialSeen(gameData.level);
		return progress;
	}

	static function offlineUserData():UserData {
		var progress = progressStore.load();
		var flags:haxe.EnumFlags<UserFlags> = cast 0;
		flags.set(UserFlags.UFMusic);
		flags.set(UserFlags.UFSFX);
		return {
			levelMax: progress.unlockedLevel,
			life: economy.livesLeft(progress),
			lastGivingLife: Date.now().getTime(),
			gold: economy.goldLeft(progress),
			arHighScore: [for (level in 0...(offlineLevels().length + 1)) progress.bestScore(level)],
			arAssets: [],
			arLoots: progress.inventory.collectedLoots(),
			pickaxe: progress.inventory.pickaxes,
			tutoDone: progress.seenTutorials().concat([for (tutorial in UNVERIFIED_TUTORIALS) if (!progress.hasSeenTutorial(tutorial)) tutorial]),
			flags: flags,
			requestsCount: 0
		};
	}

	/**
	 * The 180 levels extracted from a playthrough video by tools/levels/build_levels.py,
	 * embedded with -resource data/levels.json@levels. Enums are ["Constructor", args...].
	 */
	static function offlineLevels():Array<LevelInfo> {
		if (levels == null) {
			var records:Array<Dynamic> = haxe.Json.parse(haxe.Resource.getString("levels"));
			levels = [for (record in records) levelInfo(record)];
		}
		return levels;
	}

	static function levelInfo(record:Dynamic):LevelInfo {
		var manualRocks:Array<Dynamic> = record.arManualRocks;
		var deck:Array<Dynamic> = record.arDeck;
		return {
			level: record.level,
			version: record.version,
			numMoves: record.numMoves,
			arStepScore: record.arStepScore,
			type: goal(record.type),
			arGrip: [],
			arManualRocks: [for (rock in manualRocks) {tr: typeRock(rock.tr), x: rock.x, y: rock.y}],
			arGP: [],
			arDeck: [for (entry in deck) {t: typeRock(entry.t), v: entry.v}],
			biome: Type.createEnum(TypeBiome, record.biome[0])
		};
	}

	static function typeRock(encoded:Array<Dynamic>):TypeRock {
		if (encoded[0] == "TRBonus") {
			var bonus:Array<Dynamic> = encoded[1];
			return TypeRock.TRBonus(Type.createEnum(TypeBonus, bonus[0], bonus.slice(1)));
		}
		return Type.createEnum(TypeRock, encoded[0], encoded.slice(1));
	}

	static function goal(encoded:Array<Dynamic>):TypeGoal {
		var cells = function(list:Array<Dynamic>) return [for (cell in list) {cX: cell.cX, cY: cell.cY}];
		return switch (encoded[0]) {
			case "TGScoring": TypeGoal.TGScoring(encoded[1]);
			case "TGGelatin": TypeGoal.TGGelatin(cells(encoded[1]));
			case "TGMercury": TypeGoal.TGMercury(encoded[1], cells(encoded[2]));
			case "TGCollect":
				var targets:Array<Dynamic> = encoded[1];
				TypeGoal.TGCollect([for (target in targets) {tr: typeRock(target.tr), num: target.num}]);
			default: throw "unknown goal " + encoded[0];
		}
	}
}
