package tools;

import mt.deepnight.slb.assets.TexturePackerXml;
import mt.deepnight.slb.assets.TexturePackerXml.TexturePackerAtlas;

/**
 * Checks how TexturePacker atlases are read, in both builds (Flash and JS).
 * Run: haxe -cp . -cp client -main tools.AtlasCheck --interp
 * @spec html5.atlas::one-reader-for-both-builds
 */
class AtlasCheck {
	static inline var ASSETS = "client/client/assetsWeb/";

	static function main() {
		aTrimmedSpriteKeepsItsPlaceInItsFrame();
		folderPrefixesTurnNumberedSpritesIntoAnimationFrames();
		withoutFolderPrefixesANumberedSpriteInAFolderLosesItsWholeName();
		onlyUnderscoresAreTrimmedAfterTheTrailingNumber();
		theRawNameAlsoFindsTheSprite();
		identicalSlicesShareTheirAnimationFrame();
		anUnknownSpriteFailsWithItsName();
		anAtlasWithoutSlicesFindsNothing();
		trace("PASS");
	}

	/** @spec html5.atlas::trimmed-sprite-keeps-frame */
	static function aTrimmedSpriteKeepsItsPlaceInItsFrame() {
		var duck = readAtlas("assets1.xml", false).find("animalDuck");

		check(duck.x == 418 && duck.y == 1821, "animalDuck is cut at (418, 1821)");
		check(duck.wid == 61 && duck.hei == 67, "animalDuck is cut 61 x 67");
		check(duck.offX == -20 && duck.offY == -16, "animalDuck keeps its offset (-20, -16) in its frame");
		check(duck.fwid == 98 && duck.fhei == 98, "animalDuck keeps its 98 x 98 frame");
	}

	/** @spec html5.atlas::same-names-as-flash */
	static function folderPrefixesTurnNumberedSpritesIntoAnimationFrames() {
		var atlas = readAtlas("taupinotron.xml", true);

		check(atlas.find("gripAnim", 0).x == 1081, "gripAnim/0000 is gripAnim frame 0");
		check(atlas.find("gripAnim", 1).x == 668, "gripAnim/0001 is gripAnim frame 1");
		check(atlas.find("gripAnim", 2).x == 1333, "gripAnim/0002 is gripAnim frame 2");
	}

	/** @spec html5.atlas::same-names-as-flash */
	static function withoutFolderPrefixesANumberedSpriteInAFolderLosesItsWholeName() {
		var atlas = readAtlas("taupinotron.xml", false);

		check(!atlas.exists("gripAnim"), "without folder prefixes, gripAnim does not exist");
		check(atlas.find("", 0).x == 1081, "without folder prefixes, gripAnim/0000 is named \"\"");
	}

	/** @spec html5.atlas::same-names-as-flash */
	static function onlyUnderscoresAreTrimmedAfterTheTrailingNumber() {
		var atlas = readAtlas("fx.xml", false);

		check(atlas.find("mudPartSmall-").x == 640, "mudPartSmall-24 is named mudPartSmall-");
		check(atlas.find("mudPartSmall").x == 734, "mudPartSmall keeps its name");
	}

	/** @spec html5.atlas::same-names-as-flash */
	static function theRawNameAlsoFindsTheSprite() {
		var atlas = readAtlas("taupinotron.xml", true);

		check(atlas.find("gripAnim/0001").x == 668, "gripAnim/0001 is also found by its raw name");
	}

	/** @spec html5.atlas::same-names-as-flash */
	static function identicalSlicesShareTheirAnimationFrame() {
		var atlas = TexturePackerXml.read(
			'<TextureAtlas imagePath="test.png">'
			+ '<SubTexture name="walk0" x="0" y="0" width="8" height="8"/>'
			+ '<SubTexture name="walk1" x="8" y="0" width="8" height="8"/>'
			+ '<SubTexture name="walk2" x="0" y="0" width="8" height="8"/>'
			+ '</TextureAtlas>', false);

		check(atlas.animations.get("walk").join(",") == "0,1,0", "walk2 is the same picture as walk0: walk plays frames 0, 1, 0");
		check(!atlas.exists("walk", 2), "walk has no frame 2");
	}

	/** @spec html5.pixi-page::unknown-sprite-fails */
	static function anUnknownSpriteFailsWithItsName() {
		var atlas = readAtlas("assets1.xml", false);

		checkFailsWith(function() atlas.find("animalPlatypus"), "animalPlatypus", "an unknown sprite fails with its name");
	}

	/** @spec html5.pixi-page::unknown-sprite-fails */
	static function anAtlasWithoutSlicesFindsNothing() {
		var atlas = TexturePackerXml.read('<TextureAtlas imagePath="empty.png"></TextureAtlas>', false);

		checkFailsWith(function() atlas.find("animalDuck"), "animalDuck", "an empty atlas fails with the sprite's name");
	}

	static function readAtlas(fileName:String, treatFoldersAsPrefixes:Bool):TexturePackerAtlas {
		return TexturePackerXml.read(sys.io.File.getContent(ASSETS + fileName), treatFoldersAsPrefixes);
	}

	static function checkFailsWith(action:Void->Void, expectedInMessage:String, expectation:String) {
		var message:String = null;
		try action() catch (error:Dynamic) message = Std.string(error);
		check(message != null && message.indexOf(expectedInMessage) >= 0, expectation + " (got: " + message + ")");
	}

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}
