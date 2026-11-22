package tools;

import h2d.Bitmap;
import h2d.RenderContext;
import h2d.RenderContext.DrawCommand;
import h2d.Scene;
import h2d.Sprite;
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
