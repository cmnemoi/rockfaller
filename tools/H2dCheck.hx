package tools;

import h2d.Bitmap;
import h2d.RenderContext;
import h2d.RenderContext.DrawCommand;
import h2d.Scene;
import h2d.Sprite;
import h2d.SpriteBatch;
import h2d.Tile;

/**
 * Checks the h2d layer of the JS build: what the scene asks to draw, without PixiJS.
 * Run: mise run html5:check:h2d
 */
class H2dCheck {
	static function main() {
		aClonedTileChangesIndependently();
		aChildIsDrawnThroughItsParentsPositionAndScale();
		aFlippedBitmapIsMirroredAroundItsPivot();
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

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}
