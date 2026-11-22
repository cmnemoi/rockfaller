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
