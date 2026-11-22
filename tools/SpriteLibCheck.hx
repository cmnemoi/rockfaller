package tools;

import h2d.RenderContext;
import h2d.RenderContext.DrawCommand;
import mt.deepnight.slb.BLib;
import mt.deepnight.slb.HSprite;
import mt.deepnight.slb.assets.TexturePacker;
import mt.deepnight.slb.assets.TexturePackerXml;

/**
 * Checks the SpriteLib (BLib, HSprite, AnimManager) on the h2d layer of the JS build.
 * Run: mise run html5:check:spritelib
 */
class SpriteLibCheck {
	static inline var ASSETS = "client/client/assetsWeb/";
	static inline var GRIP_FRAMES = 16;

	static function main() {
		blibGetsTheGroupsAndAnimationsOfTheAtlas();
		anUnknownGroupHasNoFrameData();
		anHSpriteOnAnUnknownGroupFailsWithItsName();
		theFirstFrameOfAnAnimationLastsTwoUpdates();
		anAnimationPlaysItsFramesInOrderThenLoops();
		aCenteredTrimmedSpriteHasItsFrameCenterOnItsPosition();
		aCenteredTrimmedSpriteIsDrawnWithItsCutAtThePivotOffset();
		anAnimatedBatchSpriteIsDrawnWithItsCurrentFrame();
		trace("PASS");
	}

	/** @spec html5.slb::same-groups-and-anims */
	static function blibGetsTheGroupsAndAnimationsOfTheAtlas() {
		var xml = sys.io.File.getContent(ASSETS + "taupinotron.xml");
		var atlas = TexturePackerXml.read(xml, true);

		var lib = readLib("taupinotron.xml", true);

		var grip = atlas.find("gripAnim", 1);
		var frame = lib.getFrameData("gripAnim", 1);
		check(frame.x == grip.x && frame.y == grip.y && frame.wid == grip.wid && frame.hei == grip.hei, "gripAnim frame 1 is cut where the atlas says");
		check(frame.realFrame.x == grip.offX && frame.realFrame.y == grip.offY, "gripAnim frame 1 keeps its offset in its frame");
		check(frame.realFrame.realWid == grip.fwid && frame.realFrame.realHei == grip.fhei, "gripAnim frame 1 keeps its frame size");
		check(lib.getAnim("gripAnim").join(",") == atlas.animations.get("gripAnim").join(","), "gripAnim plays the atlas animation");
	}

	/** @spec html5.slb::same-groups-and-anims */
	static function anUnknownGroupHasNoFrameData() {
		var lib = readLib("assets1.xml", false);

		check(lib.getFrameData("animalPlatypus") == null, "an unknown group has no frame data");
	}

	/** @spec html5.slb::same-groups-and-anims */
	static function anHSpriteOnAnUnknownGroupFailsWithItsName() {
		var lib = readLib("assets1.xml", false);

		checkFailsWith(function() new HSprite(lib, "animalPlatypus"), "Unknown frame: animalPlatypus(0)", "an HSprite on an unknown group fails with its name");
	}

	/** @spec html5.slb::anim-steps-like-flash */
	static function theFirstFrameOfAnAnimationLastsTwoUpdates() {
		var lib = readLib("taupinotron.xml", true);
		var grip = lib.h_get("gripAnim");
		grip.a.playAndLoop("gripAnim");

		var anim = lib.getAnim("gripAnim");
		lib.updateChildren();
		check(grip.frame == anim[0], "after 1 update, gripAnim still shows its first frame");
		lib.updateChildren();
		check(grip.frame == anim[1], "after 2 updates, gripAnim shows its second frame");
	}

	/** @spec html5.slb::anim-steps-like-flash */
	static function anAnimationPlaysItsFramesInOrderThenLoops() {
		var lib = readLib("taupinotron.xml", true);
		var grip = lib.h_get("gripAnim");
		grip.a.playAndLoop("gripAnim");
		var anim = lib.getAnim("gripAnim");
		check(anim.length == GRIP_FRAMES, "gripAnim has " + GRIP_FRAMES + " frames (got " + anim.length + ")");

		var shown = [];
		for (update in 0...GRIP_FRAMES + 1) {
			lib.updateChildren();
			shown.push(grip.frame);
		}

		var expected = [for (update in 1...GRIP_FRAMES + 2) anim[(update - 1) % GRIP_FRAMES]];
		check(shown.join(",") == expected.join(","), "gripAnim shows " + expected.join(",") + " (got " + shown.join(",") + ")");
	}

	/** @spec html5.h2d::tile-drawn-at-its-place */
	static function aCenteredTrimmedSpriteHasItsFrameCenterOnItsPosition() {
		var lib = readLib("assets1.xml", false);

		var duck = lib.h_get("animalDuck", 0.5, 0.5);

		check(duck.tile.dx == -29 && duck.tile.dy == -33, "animalDuck centered has dx = -29, dy = -33 (got " + duck.tile.dx + ", " + duck.tile.dy + ")");
	}

	/** @spec html5.h2d::tile-drawn-at-its-place */
	static function aCenteredTrimmedSpriteIsDrawnWithItsCutAtThePivotOffset() {
		var lib = readLib("assets1.xml", false);
		var scene = new h2d.Scene();
		var duck = lib.h_get("animalDuck", 0.5, 0.5, scene);
		duck.setPos(100, 100);

		var drawn = render(scene);

		check(drawn.length == 1, "the scene draws the duck once (got " + drawn.length + ")");
		check(drawn[0].tx == 71 && drawn[0].ty == 67, "the duck's cut starts at (71, 67) (got " + drawn[0].tx + ", " + drawn[0].ty + ")");
		check(drawn[0].cutX == 418 && drawn[0].cutY == 1821 && drawn[0].cutWidth == 61 && drawn[0].cutHeight == 67, "the duck is cut at (418, 1821, 61 x 67)");
	}

	/** @spec html5.slb::batch-sprite-shows-its-frame */
	static function anAnimatedBatchSpriteIsDrawnWithItsCurrentFrame() {
		var lib = readLib("taupinotron.xml", true);
		var scene = new h2d.Scene();
		var batch = new h2d.SpriteBatch(lib.tile, scene);
		var grip = lib.hbe_get(batch, "gripAnim");
		grip.a.playAndLoop("gripAnim");

		for (update in 0...4)
			lib.updateChildren();
		var drawn = render(scene)[0];

		var frame = lib.getFrameData("gripAnim", grip.frame);
		check(grip.frame == lib.getAnim("gripAnim")[3], "after 4 updates, the batch sprite is on gripAnim's fourth frame");
		check(drawn.cutX == frame.x && drawn.cutY == frame.y && drawn.cutWidth == frame.wid && drawn.cutHeight == frame.hei, "the batch sprite is drawn with its current frame's cut");
	}

	static function render(scene:h2d.Scene):Array<DrawCommand> {
		var context = new RenderContext();
		scene.render(context);
		return context.drawn;
	}

	static function readLib(fileName:String, treatFoldersAsPrefixes:Bool):BLib {
		var xml = sys.io.File.getContent(ASSETS + fileName);
		return TexturePacker.parseXml(xml, null, treatFoldersAsPrefixes, h2d.Tile.fromTexture(new h3d.mat.Texture(2048, 2048)));
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
