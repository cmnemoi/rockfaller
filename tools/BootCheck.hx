package tools;

import progress.LocalStorageProgressStore;
import progress.Progress;

/**
 * Checks what the JS build needs to start the game: the progress store and the list of assets to preload.
 * Run: mise run html5:check:boot (compiled to JS, run by Node)
 */
class BootCheck {
	static inline var LAST_LEVEL = 180;

	static function main() {
		savedProgressComesBackOnTheNextVisit();
		withNothingSavedANewGameStarts();
		unavailableStorageStartsANewGameAndSavesNothing();
		theManifestListsTheGameImagesWithTheirIds();
		onlyTheLevelPathImagesKeepTheirPixels();
		theManifestListsTheSoundsTheBankAsksFor();
		trace("PASS");
	}

	/** @spec html5.boot::progress-in-local-storage */
	static function savedProgressComesBackOnTheNextVisit() {
		var storage = new FakeStorage();
		new LocalStorageProgressStore(storage).save(Progress.newGame().recordVictory(1, 4800, LAST_LEVEL));

		var loaded = new LocalStorageProgressStore(storage).load();

		check(loaded.unlockedLevel == 2 && loaded.bestScore(1) == 4800, "a won level 1 comes back: level 2 unlocked, best score 4800");
	}

	/** @spec html5.boot::progress-in-local-storage */
	static function withNothingSavedANewGameStarts() {
		var loaded = new LocalStorageProgressStore(new FakeStorage()).load();

		check(loaded.unlockedLevel == 1, "with nothing saved, a new game starts at level 1");
	}

	/** @spec html5.boot::progress-in-local-storage: like the Flash store, the game goes on without saving */
	static function unavailableStorageStartsANewGameAndSavesNothing() {
		var store = new LocalStorageProgressStore(new FakeStorage(true));

		var loaded = store.load();
		store.save(loaded);

		check(loaded.unlockedLevel == 1, "unavailable storage starts a new game, and saving does not fail");
	}

	/** @spec html5.boot::everything-preloaded */
	static function theManifestListsTheGameImagesWithTheirIds() {
		var images = [for (image in AssetManifest.IMAGES) image.id];

		check(images.indexOf("design.png") >= 0 && images.indexOf("worlds/worldMagma.png") >= 0, "design.png and worlds/worldMagma.png are listed by their ids");
		check(AssetManifest.TEXTS.indexOf("worlds/worldMagma.meta.json") >= 0, "worldMagma's meta.json is listed");
	}

	/** @spec html5.boot::everything-preloaded: pixels cost 16 MB per 2048 px atlas, ButtonLevel only reads the level paths' */
	static function onlyTheLevelPathImagesKeepTheirPixels() {
		var kept = [for (image in AssetManifest.IMAGES) if (image.keepPixels) image.id];
		kept.sort(Reflect.compare);

		check(kept.join(",") == "levels.png,levels2.png", "only levels.png and levels2.png keep their pixels (got " + kept + ")");
	}

	/** @spec html5.boot::everything-preloaded */
	static function theManifestListsTheSoundsTheBankAsksFor() {
		check(AssetManifest.SOUNDS.length == 81 && AssetManifest.SOUNDS.indexOf("Rockfaller_WIN.mp3") >= 0, "the 81 sounds are listed by file name (got " + AssetManifest.SOUNDS.length + ")");
	}

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}

/** localStorage, in memory; unavailable, every call throws like a browser with storage blocked. */
private class FakeStorage {
	var items = new Map<String, String>();
	var unavailable:Bool;

	public function new(unavailable = false) {
		this.unavailable = unavailable;
	}

	public function getItem(key:String):String {
		if (unavailable) throw "SecurityError: storage is blocked";
		return items.exists(key) ? items.get(key) : null;
	}

	public function setItem(key:String, value:String):Void {
		if (unavailable) throw "SecurityError: storage is blocked";
		items.set(key, value);
	}
}
