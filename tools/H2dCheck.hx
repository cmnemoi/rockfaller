package tools;

import h2d.Bitmap;
import h2d.RenderContext;
import h2d.RenderContext.DrawCommand;
import h2d.Scene;
import h2d.Sprite;
import h2d.SpriteBatch;
import h2d.Tile;
import hxd.Event.EventKind;

/**
 * Checks the h2d layer of the JS build: what the scene asks to draw, without PixiJS.
 * Run: mise run html5:check:h2d (compiled to JS: an Int left unset is null there, as in the browser)
 */
class H2dCheck {
	static function main() {
		aFieldLeftUnsetHasFlashsDefaultValue();
		aFrameThatFailsDoesNotStopTheGameLoop();
		drawingTheSameSceneAgainReusesItsCommands();
		aColouredQuadReusesItsColourMatrix();
		aStaticBatchKeepsTheColourItWasDrawnWith();
		onA120HzScreenTheLoopRuns30TimesPerSecond();
		onA60HzScreenTheLoopRuns30TimesPerSecond();
		onA144HzScreenTheLoopRunsAbout30TimesPerSecond();
		onAScreenSlowerThan30HzTheLoopRunsOnEveryFrame();
		frameTimesOffByAMillisecondKeepThe30CallsPerSecond();
		aClonedTileChangesIndependently();
		aChildIsDrawnThroughItsParentsPositionAndScale();
		aFlippedBitmapIsMirroredAroundItsPivot();
		aTileScaledToASizeDrawsItsWholeCutShrunk();
		aResizedTileFontDrawsWholeLettersShrunk();
		aBatchElementWithAScaledTileDrawsItsWholeCutShrunk();
		aTileGivenANewSizeCutsItsTextureToThatSize();
		childrenAreDrawnInListOrder();
		aRemovedChildIsNotDrawn();
		anInvisibleSpriteHidesItsChildren();
		anEmptyBatchDrawsNothing();
		anElementIsDrawnThroughItsBatch();
		anElementsRotationAndScaleComposeWithItsBatch();
		aRotatedElementInARotatedBatchAddsUpTheRotations();
		aHigherPriorityElementIsDrawnFirst();
		anInvisibleElementIsNotDrawn();
		anElementsAlphaIsMultipliedByItsBatchsAlpha();
		aStaticBatchKeepsItsElementsUntilInvalidated();
		aStaticBatchsElementsFollowTheBatch();
		aBatchOfMoreThan4096ElementsDrawsNothing();
		aDrawableIsDrawnWithItsBlendMode();
		aBatchsElementsAreDrawnWithTheBatchsBlendMode();
		aDrawableWithoutColorIsDrawnWithoutColorMatrix();
		aBlackColorWithAnAddedColorDrawsASilhouette();
		theColorizeMatrixOfTheGameGivesTheFlashColorizeFilter();
		alphaIsAppliedBeforeTheColorMatrix();
		aBatchElementsColorMultipliesItsPicture();
		aHigherLayerIsDrawnOverALowerOneWhateverTheOrderOfAdding();
		overPutsASpriteOnTopOfItsLayerOnly();
		underPutsASpriteAtTheBottomOfItsLayer();
		aLayerKeepsItsPlaceAfterAChildBelowIsRemoved();
		ysortDrawsALayerFromTopToBottom();
		glyphsFollowEachOtherWithTheirWidthAndTheLetterSpacing();
		aNewLineStartsALineHeightLower();
		rightAlignedTextEndsAtItsMaxWidth();
		centeredTextIsCenteredInItsMaxWidth();
		aWordThatPassesTheMaxWidthGoesToTheNextLine();
		anAccentedLetterIsDrawnWithItsGlyph();
		theTextColorColorsTheGlyphs();
		theTextAlphaFadesTheGlyphs();
		aClickOnAnInteractiveGivesItsLocalPosition();
		movingInThenOutGivesOverThenOut();
		leavingAfterThePushCancelsTheClick();
		theTopmostInteractiveTakesTheClick();
		propagatingEventsReachTheInteractiveBelow();
		anInteractiveUnderAnInvisibleParentGetsNoEvent();
		anInteractiveFlippedOnOneAxisNeverGetsTheClick();
		aRotatedInteractiveIsClickedThroughItsRotation();
		aBackgroundColorIsDrawnAsAColoredRectangle();
		aFilledRectangleIsDrawnInItsColor();
		aGraphicsFadesWithItsAlpha();
		eachFillKeepsItsOwnColor();
		aRectangleOutsideAFillDrawsNothing();
		clearRemovesTheRectangles();
		particleBoundsContainLikeFlash();
		at60HzTheTimerSettlesOnHalfAFlashFrame();
		aFrameLongerThanHalfASecondDoesNotJumpTheTimer();
		anAlphaMapIsDrawnOverItsDrawablesTile();
		aSpritesMouseIsThePointerInTheSpritesOwnSpace();
		localToGlobalGivesThePointOnTheScreen();
		trace("PASS");
	}

	static function aClonedTileChangesIndependently() {
		var tile = atlasTile().sub(10, 20, 30, 40);

		var copy = tile.clone();
		copy.setPos(1, 2);
		copy.dx = -5;

		check(tile.x == 10 && tile.y == 20 && tile.dx == 0, "changing a clone leaves the original tile as it was");
	}

	/** @spec html5.h2d::positions-compose */
	static function aChildIsDrawnThroughItsParentsPositionAndScale() {
		var scene = new Scene();
		var parent = new Sprite(scene);
		parent.setPos(10, 20);
		parent.setScale(2);
		var child = new Bitmap(atlasTile().sub(0, 0, 8, 8), parent);
		child.setPos(5, 5);

		var drawn = render(scene)[0];

		check(drawn.tx == 20 && drawn.ty == 30, "the child is drawn at (20, 30) (got " + drawn.tx + ", " + drawn.ty + ")");
		check(drawn.a == 2 && drawn.d == 2, "the child is drawn at the parent's scale of 2");
	}

	/** @spec html5.h2d::flip-keeps-pivot */
	static function aFlippedBitmapIsMirroredAroundItsPivot() {
		var scene = new Scene();
		var tile = atlasTile().sub(0, 0, 40, 8);
		tile.dx = -10;
		var flipped = new Bitmap(tile, scene);
		flipped.setPos(100, 0);
		flipped.scaleX = -1;

		var drawn = render(scene)[0];

		check(drawn.tx == 110 && drawn.a == -1, "the flipped cut starts 10 px right of the pivot and goes left (got tx " + drawn.tx + ", a " + drawn.a + ")");
	}

	/** @spec html5.h2d::tile-size-like-fork: scaleToSize keeps the texture cut, like the fork's UVs */
	static function aTileScaledToASizeDrawsItsWholeCutShrunk() {
		var scene = new Scene();
		var tile = atlasTile().sub(0, 0, 40, 20, 10, 6);
		tile.scaleToSize(20, 5);
		new Bitmap(tile, scene);

		var drawn = render(scene)[0];

		check(drawn.cutWidth == 40 && drawn.cutHeight == 20, "the whole 40 x 20 cut is drawn (got " + drawn.cutWidth + " x " + drawn.cutHeight + ")");
		check(drawn.a == 0.5 && drawn.d == 0.25 && drawn.tx == 5 && drawn.ty == 2, "shrunk to 20 x 5, its offset too (got scale " + drawn.a + ", " + drawn.d + ", at " + drawn.tx + ", " + drawn.ty + ")");
	}

	/** @spec html5.h2d::tile-size-like-fork: the game's bitmap fonts (mt.heaps.TileFont) are resized this way */
	static function aResizedTileFontDrawsWholeLettersShrunk() {
		var scene = new Scene();
		var font = @:privateAccess new h2d.Font("letters", 100);
		@:privateAccess font.glyphs.set("A".code, new h2d.Font.FontChar(atlasTile().sub(0, 0, 60, 100), 60));
		font.resizeTo(50);
		var text = new h2d.Text(font, scene);
		text.text = "A";

		var drawn = render(scene)[0];

		check(drawn.cutWidth == 60 && drawn.cutHeight == 100 && drawn.a == 0.5 && drawn.d == 0.5, "the whole letter is drawn at half size (got cut " + drawn.cutWidth + " x " + drawn.cutHeight + ", scale " + drawn.a + ", " + drawn.d + ")");
	}

	/** @spec html5.h2d::tile-size-like-fork */
	static function aBatchElementWithAScaledTileDrawsItsWholeCutShrunk() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		var tile = atlasTile().sub(0, 0, 40, 20);
		tile.scaleToSize(20, 10);
		batch.alloc(tile).scaleX = 3;

		var drawn = render(scene)[0];

		check(drawn.cutWidth == 40 && drawn.a == 1.5 && drawn.d == 0.5, "the whole cut, shrunk by the tile then scaled by the element (got cut " + drawn.cutWidth + ", scale " + drawn.a + ", " + drawn.d + ")");
	}

	/** @spec html5.h2d::tile-size-like-fork: setSize moves the cut's end, like the fork's u2 and v2 */
	static function aTileGivenANewSizeCutsItsTextureToThatSize() {
		var scene = new Scene();
		var tile = atlasTile().sub(0, 0, 40, 20);
		tile.setSize(10, 10);
		new Bitmap(tile, scene);

		var drawn = render(scene)[0];

		check(drawn.cutWidth == 10 && drawn.cutHeight == 10 && drawn.a == 1 && drawn.d == 1, "a 10 x 10 cut at scale 1 (got cut " + drawn.cutWidth + " x " + drawn.cutHeight + ", scale " + drawn.a + ")");
	}

	/** @spec html5.h2d::positions-compose */
	static function childrenAreDrawnInListOrder() {
		var scene = new Scene();
		var below = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		var above = new Bitmap(atlasTile().sub(8, 0, 8, 8), scene);

		var drawn = render(scene);

		check(drawn.length == 2 && drawn[0].cutX == 0 && drawn[1].cutX == 8, "the last child is drawn last, on top");
	}

	/** @spec html5.h2d::positions-compose */
	static function aRemovedChildIsNotDrawn() {
		var scene = new Scene();
		var kept = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		var removed = new Bitmap(atlasTile().sub(8, 0, 8, 8), scene);
		render(scene);

		removed.remove();
		var drawn = render(scene);

		check(drawn.length == 1 && drawn[0].cutX == 0, "a removed child is no longer drawn");
	}

	static function anInvisibleSpriteHidesItsChildren() {
		var scene = new Scene();
		var hidden = new Sprite(scene);
		new Bitmap(atlasTile().sub(0, 0, 8, 8), hidden);
		hidden.visible = false;

		check(render(scene).length == 0, "an invisible sprite's children are not drawn");
	}

	static function anEmptyBatchDrawsNothing() {
		var scene = new Scene();
		new SpriteBatch(atlasTile(), scene);

		check(render(scene).length == 0, "an empty batch draws nothing");
	}

	/** @spec html5.h2d.batch::element-drawn-through-batch */
	static function anElementIsDrawnThroughItsBatch() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.setPos(100, 50);
		var element = batch.alloc(atlasTile().sub(0, 0, 8, 8, -4, -6));
		element.setPos(10, 20);

		var drawn = render(scene)[0];

		check(drawn.tx == 106 && drawn.ty == 64, "the element's corner is at (106, 64) (got " + drawn.tx + ", " + drawn.ty + ")");
	}

	/** @spec html5.h2d.batch::element-drawn-through-batch */
	static function anElementsRotationAndScaleComposeWithItsBatch() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.setScale(3);
		var element = batch.alloc(atlasTile().sub(0, 0, 8, 8));
		element.setScale(2);
		element.rotation = Math.PI / 2;

		var drawn = render(scene)[0];

		check(near(drawn.a, 0) && near(drawn.b, 6) && near(drawn.c, -6) && near(drawn.d, 0),
			"the element is drawn with (a, b, c, d) = (0, 6, -6, 0) (got " + [drawn.a, drawn.b, drawn.c, drawn.d] + ")");
	}

	/** @spec html5.h2d.batch::element-drawn-through-batch */
	static function aRotatedElementInARotatedBatchAddsUpTheRotations() {
		// With a batch only scaled, b and c of the batch are 0 and a transposed composition would pass.
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.rotation = 0.3;
		var element = batch.alloc(atlasTile().sub(0, 0, 8, 8));
		element.setScale(2);
		element.rotation = 0.5;

		var drawn = render(scene)[0];

		check(near(drawn.a, 2 * Math.cos(0.8)) && near(drawn.b, 2 * Math.sin(0.8)),
			"the element is drawn turned by 0.3 + 0.5 (got a " + drawn.a + ", b " + drawn.b + ")");
	}

	/** @spec html5.h2d.batch::elements-in-list-order */
	static function aHigherPriorityElementIsDrawnFirst() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.alloc(atlasTile().sub(0, 0, 8, 8), 0);
		batch.alloc(atlasTile().sub(8, 0, 8, 8), 5);

		var drawn = render(scene);

		check(drawn.length == 2 && drawn[0].cutX == 8 && drawn[1].cutX == 0, "the priority 5 element is drawn first, behind");
	}

	/** @spec html5.h2d.batch::elements-in-list-order */
	static function anInvisibleElementIsNotDrawn() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.alloc(atlasTile().sub(0, 0, 8, 8)).visible = false;
		batch.alloc(atlasTile().sub(8, 0, 8, 8));

		var drawn = render(scene);

		check(drawn.length == 1 && drawn[0].cutX == 8, "an invisible element is not drawn");
	}

	/** @spec html5.h2d.batch::element-alpha-times-batch-alpha */
	static function anElementsAlphaIsMultipliedByItsBatchsAlpha() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.alpha = 0.5;
		batch.alloc(atlasTile().sub(0, 0, 8, 8)).alpha = 0.5;

		check(render(scene)[0].alpha == 0.25, "the element is drawn at alpha 0.25");
	}

	/** @spec html5.h2d.batch::static-until-invalidate */
	static function aStaticBatchKeepsItsElementsUntilInvalidated() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.optimizeForStatic(true);
		var element = batch.alloc(atlasTile().sub(0, 0, 8, 8));
		render(scene);

		element.setPos(30, 0);
		var beforeInvalidate = render(scene)[0].tx;
		batch.invalidate();
		var afterInvalidate = render(scene)[0].tx;

		check(beforeInvalidate == 0, "a static batch still draws a moved element at its old place (got " + beforeInvalidate + ")");
		check(afterInvalidate == 30, "after invalidate(), the element is drawn at its new place (got " + afterInvalidate + ")");
	}

	/** @spec html5.h2d.batch::static-until-invalidate */
	static function aStaticBatchsElementsFollowTheBatch() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.optimizeForStatic(true);
		batch.alloc(atlasTile().sub(0, 0, 8, 8));
		render(scene);

		batch.setPos(50, 0);

		check(render(scene)[0].tx == 50, "a static batch's elements follow the batch");
	}

	/** @spec html5.h2d.batch::too-many-elements-draws-nothing */
	static function aBatchOfMoreThan4096ElementsDrawsNothing() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		for (index in 0...4097)
			batch.alloc(atlasTile().sub(0, 0, 8, 8));

		check(render(scene).length == 0, "a batch of 4097 elements draws nothing");
	}

	/** @spec html5.h2d.color::blend-mode-like-fork */
	static function aDrawableIsDrawnWithItsBlendMode() {
		var scene = new Scene();
		var normal = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		var added = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		added.blendMode = h2d.BlendMode.Add;

		var drawn = render(scene);

		check(drawn[0].blendMode == h2d.BlendMode.Normal, "a drawable is drawn in Normal mode by default");
		check(drawn[1].blendMode == h2d.BlendMode.Add, "a drawable in Add mode is drawn in Add mode");
	}

	/** @spec html5.h2d.color::blend-mode-like-fork */
	static function aBatchsElementsAreDrawnWithTheBatchsBlendMode() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.blendMode = h2d.BlendMode.SoftOverlay;
		batch.alloc(atlasTile().sub(0, 0, 8, 8));

		check(render(scene)[0].blendMode == h2d.BlendMode.SoftOverlay, "a batch's elements are drawn in the batch's mode");
	}

	/** @spec html5.h2d.color::color-like-fork-shader */
	static function aDrawableWithoutColorIsDrawnWithoutColorMatrix() {
		var scene = new Scene();
		var bitmap = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		bitmap.alpha = 0.5;

		var drawn = render(scene)[0];

		check(drawn.colorMatrix == null && drawn.alpha == 0.5, "a drawable without color is drawn with its alpha only, no color matrix");
	}

	/** @spec html5.h2d.color::color-like-fork-shader: the loot silhouettes of Collection */
	static function aBlackColorWithAnAddedColorDrawsASilhouette() {
		var scene = new Scene();
		var bitmap = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		bitmap.color = new h3d.Vector();
		bitmap.colorAdd = h3d.Vector.fromColor(0x00483929);

		var matrix = render(scene)[0].colorMatrix;

		check(sameMatrix(matrix, [
			0, 0, 0, 0, 0x48 / 255,
			0, 0, 0, 0, 0x39 / 255,
			0, 0, 0, 0, 0x29 / 255,
			0, 0, 0, 1, 0,
		]), "black plus 0x483929 draws a brown silhouette that keeps the picture's alpha (got " + matrix + ")");
	}

	/** @spec html5.h2d.color::color-like-fork-shader: the world rollover of ButtonWorld */
	static function theColorizeMatrixOfTheGameGivesTheFlashColorizeFilter() {
		var scene = new Scene();
		var bitmap = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		bitmap.colorMatrix = mt.deepnight.Color.getColorizeMatrixH2d(0xECB96C, 0.5, 0.5);

		var matrix = render(scene)[0].colorMatrix;

		// The rows of mt.deepnight.Color.getColorizeFilter(0xECB96C, 0.5, 0.5), the Flash version of the same effect.
		var r = 0.5 * 0xEC / 255, g = 0.5 * 0xB9 / 255, b = 0.5 * 0x6C / 255;
		check(sameMatrix(matrix, [
			0.5 + r, r, r, 0, 0,
			g, 0.5 + g, g, 0, 0,
			b, b, 0.5 + b, 0, 0,
			0, 0, 0, 1, 0,
		]), "the colorize matrix gives the rows of the Flash colorize filter (got " + matrix + ")");
	}

	/** @spec html5.h2d.color::color-like-fork-shader */
	static function alphaIsAppliedBeforeTheColorMatrix() {
		var scene = new Scene();
		var bitmap = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		bitmap.alpha = 0.5;
		bitmap.colorAdd = new h3d.Vector(0, 0, 0, 0.25);

		var drawn = render(scene)[0];

		check(drawn.alpha == 1 && drawn.colorMatrix[18] == 0.5 && drawn.colorMatrix[19] == 0.25,
			"alpha 0.5 goes into the matrix before the added 0.25: a' = 0.5 a + 0.25 (got alpha " + drawn.alpha + ", " + drawn.colorMatrix + ")");
	}

	/** @spec html5.h2d.color::color-like-fork-shader */
	static function aBatchElementsColorMultipliesItsPicture() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.alloc(atlasTile().sub(0, 0, 8, 8)).color = new h3d.Vector(0.5, 1, 1, 1);

		var matrix = render(scene)[0].colorMatrix;

		check(matrix != null && matrix[0] == 0.5 && matrix[6] == 1, "an element colored (0.5, 1, 1) halves its red (got " + matrix + ")");
	}

	/** @spec html5.h2d.layers::drawn-by-layer */
	static function aHigherLayerIsDrawnOverALowerOneWhateverTheOrderOfAdding() {
		var scene = new Scene();
		var layers = new h2d.Layers(scene);
		layers.add(bitmapCutAt(16), 2);
		layers.add(bitmapCutAt(0), 0);

		check(cutsDrawn(scene) == "0,16", "layer 0 is drawn under layer 2, though added after it (got " + cutsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.layers::drawn-by-layer */
	static function overPutsASpriteOnTopOfItsLayerOnly() {
		var scene = new Scene();
		var layers = new h2d.Layers(scene);
		var first = bitmapCutAt(0);
		layers.add(first, 0);
		layers.add(bitmapCutAt(8), 0);
		layers.add(bitmapCutAt(16), 1);

		layers.over(first);

		check(cutsDrawn(scene) == "8,0,16", "over() puts a sprite on top of its layer, still under layer 1 (got " + cutsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.layers::drawn-by-layer */
	static function underPutsASpriteAtTheBottomOfItsLayer() {
		var scene = new Scene();
		var layers = new h2d.Layers(scene);
		layers.add(bitmapCutAt(0), 0);
		layers.add(bitmapCutAt(8), 1);
		var last = bitmapCutAt(16);
		layers.add(last, 1);

		layers.under(last);

		check(cutsDrawn(scene) == "0,16,8", "under() puts a sprite at the bottom of its layer, still over layer 0 (got " + cutsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.layers::drawn-by-layer */
	static function aLayerKeepsItsPlaceAfterAChildBelowIsRemoved() {
		var scene = new Scene();
		var layers = new h2d.Layers(scene);
		var removed = bitmapCutAt(0);
		layers.add(removed, 0);
		layers.add(bitmapCutAt(8), 0);
		layers.add(bitmapCutAt(16), 1);

		removed.remove();
		layers.add(bitmapCutAt(24), 0);

		check(cutsDrawn(scene) == "8,24,16", "a child added to layer 0 after a removal still goes under layer 1 (got " + cutsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.layers::drawn-by-layer */
	static function ysortDrawsALayerFromTopToBottom() {
		var scene = new Scene();
		var layers = new h2d.Layers(scene);
		var low = bitmapCutAt(0);
		low.y = 50;
		var high = bitmapCutAt(8);
		high.y = 10;
		layers.add(low, 0);
		layers.add(high, 0);

		layers.ysort(0);

		check(cutsDrawn(scene) == "8,0", "ysort draws the sprite higher on screen first (got " + cutsDrawn(scene) + ")");
	}

	/** @spec html5::flash-default-values */
	static function aFieldLeftUnsetHasFlashsDefaultValue() {
		var unset = new FieldsLeftUnset();

		check(unset.count == 0 && unset.ratio == 0 && unset.shown == false && unset.name == null, "unset Int, Float and Bool fields are 0, 0 and false, a String stays null");
		check(10 + unset.count == 10, "10 + an unset Int is 10, not NaN");
	}

	/** A font drawn by hand: A is 6 px wide, B 7, the space 3, é 6; lines are 10 px high. */
	static function testFont():h2d.Font {
		var font = @:privateAccess new h2d.Font("test", 10);
		@:privateAccess font.lineHeight = 10;
		@:privateAccess font.tile = atlasTile();
		var glyphs:Map<Int, h2d.Font.FontChar> = @:privateAccess font.glyphs;
		glyphs.set("A".code, new h2d.Font.FontChar(atlasTile().sub(0, 0, 5, 8), 6));
		glyphs.set("B".code, new h2d.Font.FontChar(atlasTile().sub(8, 0, 6, 8), 7));
		glyphs.set(" ".code, new h2d.Font.FontChar(atlasTile().sub(16, 0, 2, 8), 3));
		glyphs.set(0xE9, new h2d.Font.FontChar(atlasTile().sub(24, 0, 5, 8), 6));
		return font;
	}

	static function textIn(scene:Scene, text:String):h2d.Text {
		var shown = new h2d.Text(testFont(), scene);
		shown.text = text;
		return shown;
	}

	static function glyphsDrawn(scene:Scene):String {
		return [for (command in render(scene)) command.cutX + "@" + command.tx + "," + command.ty].join(" ");
	}

	/** @spec html5.h2d.text::layout-like-fork */
	static function glyphsFollowEachOtherWithTheirWidthAndTheLetterSpacing() {
		var scene = new Scene();
		textIn(scene, "AB");

		check(glyphsDrawn(scene) == "0@0,0 8@7,0", "B starts after A's 6 px and 1 px of letter spacing (got " + glyphsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.text::layout-like-fork */
	static function aNewLineStartsALineHeightLower() {
		var scene = new Scene();
		textIn(scene, "A\nB");

		check(glyphsDrawn(scene) == "0@0,0 8@0,10", "B starts a 10 px line lower, and the new line draws nothing (got " + glyphsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.text::layout-like-fork */
	static function rightAlignedTextEndsAtItsMaxWidth() {
		var scene = new Scene();
		var text = textIn(scene, "AB");
		text.maxWidth = 30;
		text.textAlign = h2d.Text.Align.Right;

		check(glyphsDrawn(scene) == "0@15,0 8@22,0", "AB (15 px with its spacing) ends at 30 px (got " + glyphsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.text::layout-like-fork */
	static function centeredTextIsCenteredInItsMaxWidth() {
		var scene = new Scene();
		var text = textIn(scene, "AB");
		text.maxWidth = 30;
		text.textAlign = h2d.Text.Align.Center;

		check(glyphsDrawn(scene) == "0@7,0 8@14,0", "AB starts at (30 - 15) >> 1 = 7 px (got " + glyphsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.text::layout-like-fork */
	static function aWordThatPassesTheMaxWidthGoesToTheNextLine() {
		var scene = new Scene();
		var text = textIn(scene, "A AB");
		text.maxWidth = 12;

		check(glyphsDrawn(scene) == "0@0,0 0@0,10 8@7,10", "AB does not fit in 12 px after \"A \": it starts the next line, and the space is dropped (got " + glyphsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.text::layout-like-fork */
	static function anAccentedLetterIsDrawnWithItsGlyph() {
		var scene = new Scene();
		textIn(scene, "\u00E9");

		check(glyphsDrawn(scene) == "24@0,0", "é is drawn with its own glyph (got " + glyphsDrawn(scene) + ")");
	}

	/** @spec html5.h2d.text::layout-like-fork */
	static function theTextColorColorsTheGlyphs() {
		var scene = new Scene();
		textIn(scene, "A").textColor = 0xFF0000;

		var matrix = render(scene)[0].colorMatrix;

		check(matrix != null && matrix[0] == 1 && matrix[6] == 0 && matrix[12] == 0, "a red text keeps only the red of its glyphs (got " + matrix + ")");
	}

	/** @spec html5.h2d.text::layout-like-fork: the text shares its shader with its glyphs, like the fork */
	static function theTextAlphaFadesTheGlyphs() {
		var scene = new Scene();
		textIn(scene, "A").alpha = 0.5;

		var drawn = render(scene)[0];

		check(drawn.alpha == 0.5 || (drawn.colorMatrix != null && drawn.colorMatrix[18] == 0.5), "a text at alpha 0.5 draws its glyphs at alpha 0.5 (got alpha " + drawn.alpha + ", " + drawn.colorMatrix + ")");
	}

	/** An interactive of 50 x 30 px at (100, 100), and what it was told. */
	static function interactiveIn(parent:Sprite, ?x = 100.0, ?y = 100.0):{interactive:h2d.Interactive, heard:Array<String>} {
		var interactive = new h2d.Interactive(50, 30, parent);
		interactive.setPos(x, y);
		var heard = [];
		interactive.onPush = function(e) heard.push("push");
		interactive.onRelease = function(e) heard.push("release");
		interactive.onClick = function(e) heard.push("click@" + Math.round(e.relX) + "," + Math.round(e.relY));
		interactive.onOver = function(e) heard.push("over");
		interactive.onOut = function(e) heard.push("out");
		return {interactive: interactive, heard: heard};
	}

	/** Sends pointer events to the scene as the stage would, then lets the scene dispatch them, as Process.updateAll does. */
	static function pointer(scene:Scene, kind:hxd.Event.EventKind, x:Float, y:Float) {
		// A frame of the game loop first: like the fork, the scene only queues events once checkEvents has run.
		render(scene);
		scene.checkEvents();
		@:privateAccess scene.onEvent(new hxd.Event(kind, x, y));
		scene.checkEvents();
	}

	static function click(scene:Scene, x:Float, y:Float) {
		pointer(scene, EPush, x, y);
		pointer(scene, ERelease, x, y);
	}

	/** @spec html5.h2d.interactive::events-like-fork */
	static function aClickOnAnInteractiveGivesItsLocalPosition() {
		var scene = new Scene();
		var button = interactiveIn(scene);

		click(scene, 110, 120);

		check(button.heard.join(" ") == "push release click@10,20", "a click at (110, 120) reaches the interactive at (10, 20) (got " + button.heard + ")");
	}

	/** @spec html5.h2d.interactive::events-like-fork */
	static function movingInThenOutGivesOverThenOut() {
		var scene = new Scene();
		var button = interactiveIn(scene);

		pointer(scene, EMove, 0, 0);
		pointer(scene, EMove, 110, 110);
		pointer(scene, EMove, 300, 300);

		check(button.heard.join(" ") == "over out", "moving in then out gives over then out (got " + button.heard + ")");
	}

	/** @spec html5.h2d.interactive::events-like-fork */
	static function leavingAfterThePushCancelsTheClick() {
		var scene = new Scene();
		var button = interactiveIn(scene);

		pointer(scene, EMove, 110, 110);
		pointer(scene, EPush, 110, 110);
		pointer(scene, EMove, 300, 300);
		pointer(scene, ERelease, 300, 300);

		check(button.heard.join(" ") == "over push out release", "pushing, leaving, then releasing outside does not click (got " + button.heard + ")");
	}

	/** @spec html5.h2d.interactive::events-like-fork */
	static function theTopmostInteractiveTakesTheClick() {
		var scene = new Scene();
		var below = interactiveIn(scene);
		var above = interactiveIn(scene);

		click(scene, 110, 110);

		check(below.heard.length == 0 && above.heard.join(" ") == "push release click@10,10", "the interactive added last, on top, takes the click (got below " + below.heard + ", above " + above.heard + ")");
	}

	/** @spec html5.h2d.interactive::events-like-fork */
	static function propagatingEventsReachTheInteractiveBelow() {
		var scene = new Scene();
		var below = interactiveIn(scene);
		var above = interactiveIn(scene);
		above.interactive.propagateEvents = true;

		click(scene, 110, 110);

		check(above.heard.indexOf("click@10,10") >= 0 && below.heard.indexOf("click@10,10") >= 0, "with propagateEvents, the click also reaches the interactive below (got below " + below.heard + ", above " + above.heard + ")");
	}

	/** @spec html5.h2d.interactive::events-like-fork */
	static function anInteractiveUnderAnInvisibleParentGetsNoEvent() {
		var scene = new Scene();
		var hidden = new Sprite(scene);
		var button = interactiveIn(hidden);
		hidden.visible = false;

		click(scene, 110, 110);

		check(button.heard.length == 0, "an interactive under an invisible parent gets no event (got " + button.heard + ")");
	}

	/** @spec html5.h2d.interactive::events-like-fork: a quirk of the fork, kept */
	static function anInteractiveFlippedOnOneAxisNeverGetsTheClick() {
		var scene = new Scene();
		var button = interactiveIn(scene);
		button.interactive.scaleX = -1;

		click(scene, 90, 110);

		check(button.heard.length == 0, "the fork's hit test rejects a matrix flipped on one axis: no click (got " + button.heard + ")");
	}

	/** @spec html5.h2d.interactive::events-like-fork */
	static function aRotatedInteractiveIsClickedThroughItsRotation() {
		var scene = new Scene();
		var button = interactiveIn(scene);
		button.interactive.rotation = Math.PI / 2;

		click(scene, 90, 110);

		check(button.heard.join(" ") == "push release click@10,10", "turned a quarter, the interactive's (10, 10) is at (90, 110) (got " + button.heard + ")");
	}

	/** @spec html5.h2d.interactive::background-color */
	static function aBackgroundColorIsDrawnAsAColoredRectangle() {
		var scene = new Scene();
		var button = interactiveIn(scene);
		button.interactive.backgroundColor = 0x80FF0000;

		var drawn = render(scene);

		check(drawn.length == 1 && drawn[0].a == 50 && drawn[0].d == 30 && drawn[0].tx == 100 && drawn[0].ty == 100,
			"a background of 50 x 30 is drawn at (100, 100) (got " + drawn.length + " commands)");
		var matrix = drawn[0].colorMatrix;
		check(matrix != null && near(matrix[0], 1) && near(matrix[6], 0) && near(matrix[18], 0x80 / 255), "it is red at alpha 0x80 (got " + matrix + ")");
	}

	/** The transition's black screen of ProcessManager: a black rectangle over the whole stage. */
	static function blackScreenIn(scene:Scene):h2d.Graphics {
		var blackScreen = new h2d.Graphics(scene);
		blackScreen.beginFill(0xFF000000);
		blackScreen.drawRect(0, 0, 640, 768);
		blackScreen.endFill();
		return blackScreen;
	}

	/** @spec html5.h2d.graphics::filled-rectangles */
	static function aFilledRectangleIsDrawnInItsColor() {
		var scene = new Scene();
		blackScreenIn(scene);

		var drawn = render(scene);

		check(drawn.length == 1 && drawn[0].a == 640 && drawn[0].d == 768 && drawn[0].tx == 0 && drawn[0].ty == 0, "the black screen covers 640 x 768 from (0, 0)");
		var matrix = drawn[0].colorMatrix;
		check(matrix != null && matrix[0] == 0 && matrix[6] == 0 && matrix[12] == 0 && matrix[18] == 1, "it is opaque black (got " + matrix + ")");
	}

	/** @spec html5.h2d.graphics::filled-rectangles */
	static function aGraphicsFadesWithItsAlpha() {
		var scene = new Scene();
		blackScreenIn(scene).alpha = 0.5;

		var matrix = render(scene)[0].colorMatrix;

		check(matrix[18] == 0.5, "the black screen at alpha 0.5 is drawn half transparent (got " + matrix + ")");
	}

	/** @spec html5.h2d.graphics::filled-rectangles */
	static function eachFillKeepsItsOwnColor() {
		var scene = new Scene();
		var graphics = new h2d.Graphics(scene);
		graphics.beginFill(0xFF0000);
		graphics.drawRect(0, 0, 10, 10);
		graphics.beginFill(0x0000FF, 0.5);
		graphics.drawRect(20, 0, 10, 10);
		graphics.endFill();

		var drawn = render(scene);

		check(drawn.length == 2 && drawn[0].colorMatrix[0] == 1 && drawn[1].colorMatrix[12] == 1 && drawn[1].colorMatrix[18] == 0.5 && drawn[1].tx == 20,
			"a red rectangle, then a half-transparent blue one at x = 20");
	}

	/** @spec html5.h2d.graphics::filled-rectangles */
	static function aRectangleOutsideAFillDrawsNothing() {
		var scene = new Scene();
		new h2d.Graphics(scene).drawRect(0, 0, 10, 10);

		check(render(scene).length == 0, "a rectangle drawn without beginFill draws nothing");
	}

	/** @spec html5.h2d.graphics::filled-rectangles */
	static function clearRemovesTheRectangles() {
		var scene = new Scene();
		blackScreenIn(scene).clear();

		check(render(scene).length == 0, "clear() removes the rectangles");
	}

	/** flash.geom.Rectangle.contains: the left and top edges are in, the right and bottom edges are out. */
	static function particleBoundsContainLikeFlash() {
		var bounds = new mt.deepnight.HParticle.HParticleBounds(10, 20, 30, 40);

		check(bounds.contains(10, 20) && bounds.contains(39.9, 59.9), "the top-left corner and the inside are in");
		check(!bounds.contains(40, 30) && !bounds.contains(20, 60) && !bounds.contains(9.9, 30), "the right and bottom edges, and what is left of x, are out");
	}

	/** The game runs at Flash's 30 frames per second: on a 60 Hz screen, a frame is half a Flash frame. */
	static function at60HzTheTimerSettlesOnHalfAFlashFrame() {
		hxd.Timer.calc_tmod = 1;
		for (frame in 0...200) {
			hxd.Timer.oldTime = haxe.Timer.stamp() - 1 / 60;
			hxd.Timer.update();
		}

		check(Math.abs(hxd.Timer.tmod - 0.5) < 0.01, "at 60 Hz, tmod settles on 0.5 (got " + hxd.Timer.tmod + ")");
	}

	/** Like the fork: a frame longer than maxDeltaTime (0.5 s) counts as one Flash frame and leaves tmod alone. */
	static function aFrameLongerThanHalfASecondDoesNotJumpTheTimer() {
		hxd.Timer.calc_tmod = 1;
		hxd.Timer.oldTime = haxe.Timer.stamp() - 2;

		hxd.Timer.update();

		check(hxd.Timer.tmod == 1 && Math.abs(hxd.Timer.deltaT - 1 / 30) < 1e-9, "a 2 s frame keeps tmod at 1 and counts 1/30 s (got " + hxd.Timer.tmod + ", " + hxd.Timer.deltaT + ")");
	}

	/** @spec html5.h2d.color::alpha-map: the tutorial's spotlight, a black veil whose alpha follows a mask's red. */
	static function anAlphaMapIsDrawnOverItsDrawablesTile() {
		var scene = new Scene();
		var veil = new Bitmap(Tile.fromColor(0xFF000000, 640, 768), scene);
		var mask = Tile.fromColor(0xFFFFFFFF, 640, 768);
		veil.alphaMap = mask;

		var drawn = render(scene)[0];

		check(drawn.alphaMap != null && drawn.alphaMap.texture == mask.getTexture(), "the veil is drawn with its mask's texture");
		check(drawn.alphaMap.cutWidth == 640 && drawn.alphaMap.cutHeight == 768, "the mask covers the veil's 640 x 768");
	}

	/** @spec html5.h2d::mouse-in-sprite-space: the game finds the rock under the pointer with cRocks.mouseX */
	static function aSpritesMouseIsThePointerInTheSpritesOwnSpace() {
		var scene = new Scene();
		var rocks = new Sprite(scene);
		rocks.setPos(100, 50);
		rocks.setScale(2);
		render(scene);

		hxd.Stage.getInstance().event(new hxd.Event(EMove, 120, 70));

		check(rocks.mouseX == 10 && rocks.mouseY == 10, "the pointer at (120, 70) is at (10, 10) in a sprite at (100, 50) of scale 2 (got " + rocks.mouseX + ", " + rocks.mouseY + ")");
	}

	/** @spec html5.h2d::mouse-in-sprite-space: the tutorial places its bubbles with localToGlobal */
	static function localToGlobalGivesThePointOnTheScreen() {
		var scene = new Scene();
		var rocks = new Sprite(scene);
		rocks.setPos(100, 50);
		rocks.setScale(2);
		render(scene);

		var onScreen = rocks.localToGlobal(new h2d.col.Point(10, 10));

		check(onScreen.x == 120 && onScreen.y == 70, "(10, 10) in that sprite is (120, 70) on the screen (got " + onScreen.x + ", " + onScreen.y + ")");
	}

	static function bitmapCutAt(cutX:Int):Bitmap {
		return new Bitmap(atlasTile().sub(cutX, 0, 8, 8));
	}

	static function cutsDrawn(scene:Scene):String {
		return [for (command in render(scene)) command.cutX].join(",");
	}

	static function sameMatrix(matrix:Array<Float>, expected:Array<Float>) {
		if (matrix == null || matrix.length != expected.length) return false;
		for (index in 0...expected.length)
			if (!near(matrix[index], expected[index])) return false;
		return true;
	}

	static function near(value:Float, expected:Float) {
		return Math.abs(value - expected) < 1e-9;
	}

	static function atlasTile():Tile {
		return Tile.fromTexture(new h3d.mat.Texture(64, 64));
	}

	static function render(scene:Scene):Array<DrawCommand> {
		var context = new RenderContext();
		scene.render(context);
		return context.drawn;
	}

	/** @spec html5.h2d::loop-survives-errors: like Flash's ENTER_FRAME; one error froze the end of level's Next button */
	static function aFrameThatFailsDoesNotStopTheGameLoop() {
		var calls = 0;
		loopOnFrames([0, 40], function() {
			calls++;
			if (calls == 1) throw "a frame fails";
		});

		check(calls == 2, "after a frame throws, the next frame still runs (got " + calls + " frames)");
	}

	/** @spec html5.h2d::commands-reused: about 1 MB of garbage per frame came from new commands */
	static function drawingTheSameSceneAgainReusesItsCommands() {
		var scene = new Scene();
		new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.alloc(atlasTile().sub(0, 0, 8, 8));
		var context = new RenderContext();
		scene.render(context);
		var first = context.drawn.copy();

		scene.render(context);

		check(context.drawn.length == 2 && context.drawn[0] == first[0] && context.drawn[1] == first[1], "the second frame draws with the first frame's command objects");
	}

	/** @spec html5.h2d::commands-reused */
	static function aColouredQuadReusesItsColourMatrix() {
		var scene = new Scene();
		var bitmap = new Bitmap(atlasTile().sub(0, 0, 8, 8), scene);
		bitmap.color = new h3d.Vector(0.5, 1, 1, 1);
		var context = new RenderContext();
		scene.render(context);
		var first = context.drawn[0].colorMatrix;
		bitmap.color = new h3d.Vector(0.25, 1, 1, 1);

		scene.render(context);

		check(context.drawn[0].colorMatrix == first && first[0] == 0.25, "the second frame writes the new colour into the same matrix (got red factor " + first[0] + ")");
	}

	/** @spec html5.h2d.batch::static-until-invalidate: a static batch keeps its element's colour until invalidated, like its place */
	static function aStaticBatchKeepsTheColourItWasDrawnWith() {
		var scene = new Scene();
		var batch = new SpriteBatch(atlasTile(), scene);
		batch.optimizeForStatic(true);
		var element = batch.alloc(atlasTile().sub(0, 0, 8, 8));
		element.color = new h3d.Vector(0.5, 1, 1, 1);
		render(scene);

		element.color.x = 0.25;
		var redFactor = render(scene)[0].colorMatrix[0];

		check(redFactor == 0.5, "a static batch still draws its element with its first colour (got " + redFactor + ")");
	}

	/** @spec html5.h2d::loop-at-stage-rate: Flash called ENTER_FRAME 30 times per second, the stage's rate */
	static function onA120HzScreenTheLoopRuns30TimesPerSecond() {
		var calls = loopCallsInOneSecond(120, 0);

		check(calls == 30, "at 120 Hz, the loop runs 30 times in a second (got " + calls + ")");
	}

	/** @spec html5.h2d::loop-at-stage-rate */
	static function onA60HzScreenTheLoopRuns30TimesPerSecond() {
		var calls = loopCallsInOneSecond(60, 0);

		check(calls == 30, "at 60 Hz, the loop runs 30 times in a second (got " + calls + ")");
	}

	/** @spec html5.h2d::loop-at-stage-rate: every 4th or 5th frame; the game's Timer counts the steps */
	static function onA144HzScreenTheLoopRunsAbout30TimesPerSecond() {
		var calls = loopCallsInOneSecond(144, 0);

		check(calls >= 28 && calls <= 30, "at 144 Hz, the loop runs 28 to 30 times in a second (got " + calls + ")");
	}

	/** @spec html5.h2d::loop-at-stage-rate */
	static function onAScreenSlowerThan30HzTheLoopRunsOnEveryFrame() {
		var at30 = loopCallsInOneSecond(30, 0);
		var at20 = loopCallsInOneSecond(20, 0);

		check(at30 == 30 && at20 == 20, "at 30 Hz and 20 Hz, the loop runs on every frame (got " + at30 + ", " + at20 + ")");
	}

	/** @spec html5.h2d::loop-at-stage-rate: animation frame timestamps are not exact */
	static function frameTimesOffByAMillisecondKeepThe30CallsPerSecond() {
		var calls = loopCallsInOneSecond(120, 1);

		check(calls >= 29 && calls <= 31, "at 120 Hz with times off by 1 ms, the loop runs 30 times, give or take 1 (got " + calls + ")");
	}

	/** How many times the loop runs over one second of screen frames, each frame time off by jitter ms, in turns. */
	static function loopCallsInOneSecond(hertz:Int, jitter:Float):Int {
		var calls = 0;
		var frameMs = 1000 / hertz;
		loopOnFrames([for (frame in 0...hertz) frame * frameMs + (frame % 2 == 0 ? jitter : -jitter)], function() calls++);
		return calls;
	}

	/** Runs the game loop on fake animation frames at the given times, then lets it stop. */
	static function loopOnFrames(frameTimes:Array<Float>, loop:Void->Void) {
		var frames:Array<Float->Void> = [];
		js.Syntax.code("globalThis.window = {0}", {requestAnimationFrame: function(frame) frames.push(frame)});
		hxd.System.setLoop(loop);
		for (time in frameTimes)
			try frames.shift()(time) catch (_:Dynamic) {}
		hxd.System.setLoop(null);
		frames.shift()(frameTimes[frameTimes.length - 1] + 1000); // finds no loop, and stops asking for frames
		js.Syntax.code("delete globalThis.window");
	}

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}

private class FieldsLeftUnset {
	public var count:Int;
	public var ratio:Float;
	public var shown:Bool;
	public var name:String;

	public function new() {}
}
