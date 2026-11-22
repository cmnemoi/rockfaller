import h2d.RenderContext.DrawCommand;
import pixi.core.display.Container;
import pixi.core.math.Matrix;
import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;
import pixi.filters.colormatrix.ColorMatrixFilter;

/**
 * Shows the h2d layer's draw commands with PixiJS: one PixiJS sprite per command, in drawing order.
 * @spec html5.h2d::tile-drawn-at-its-place
 */
class PixiRenderer {
	// PixiJS has no SoftAdd nor SoftOverlay: they get ids of their own, past PixiJS's.
	static inline var SOFT_ADD = 100;
	static inline var SOFT_OVERLAY = 101;

	public var root(default, null):Container;
	var sprites:Array<Sprite>;

	public function new(pixiRenderer:Dynamic) {
		root = new Container();
		sprites = [];
		addBlendModesMissingFromPixi(pixiRenderer);
	}

	/**
	 * @spec html5.h2d.color::blend-mode-like-fork: the fork's SoftAdd and SoftOverlay are GPU factor pairs, which PixiJS can take as they are.
	 * PixiJS also looks every mode up in its premultiplied-alpha table, where a missing id would give no mode at all.
	 */
	static function addBlendModesMissingFromPixi(pixiRenderer:Dynamic) {
		var gl = pixiRenderer.gl;
		var factorsByMode:Array<Array<Int>> = pixiRenderer.state.blendModes;
		factorsByMode[SOFT_ADD] = [gl.ONE_MINUS_DST_COLOR, gl.ONE];
		factorsByMode[SOFT_OVERLAY] = [gl.DST_COLOR, gl.ONE];
		var modeByAlphaMode:Array<Array<Int>> = untyped PIXI.utils.premultiplyBlendMode;
		for (modes in modeByAlphaMode) {
			modes[SOFT_ADD] = SOFT_ADD;
			modes[SOFT_OVERLAY] = SOFT_OVERLAY;
		}
	}

	/**
	 * @spec html5.h2d.color::color-like-fork-shader: PixiJS's ColorMatrixFilter works on straight colors, like the fork's shader.
	 * A sprite keeps its filter, so turning a color on and off does not compile a new one each time.
	 */
	static function showColor(sprite:Sprite, colorMatrix:Array<Float>) {
		if (colorMatrix == null) {
			if (sprite.filters != null) sprite.filters = null;
			return;
		}
		var filter:ColorMatrixFilter = untyped sprite.__colorFilter;
		if (filter == null) {
			filter = new ColorMatrixFilter();
			untyped sprite.__colorFilter = filter;
		}
		filter.matrix = colorMatrix;
		if (sprite.filters == null) sprite.filters = [filter];
	}

	/** The PixiJS mode with the fork's factor pair (Drawable.setupShader), for premultiplied textures. */
	static function pixiBlendModeOf(mode:h2d.BlendMode):Int {
		var pixiModes:Dynamic = untyped PIXI.BLEND_MODES;
		return switch (mode) {
			case null | Normal: pixiModes.NORMAL;
			case Add: pixiModes.ADD;
			case Multiply: pixiModes.MULTIPLY;
			case None: pixiModes.NONE;
			case Screen: pixiModes.SCREEN;
			case Erase: pixiModes.ERASE;
			case SoftAdd: SOFT_ADD;
			case SoftOverlay: SOFT_OVERLAY;
		}
	}

	public function show(commands:Array<DrawCommand>) {
		for (index in 0...commands.length)
			showCommand(spriteAt(index), commands[index]);
		for (index in commands.length...sprites.length)
			sprites[index].visible = false;
	}

	function spriteAt(index:Int):Sprite {
		if (index == sprites.length) {
			var sprite = new Sprite(Texture.EMPTY);
			sprites.push(sprite);
			root.addChild(sprite);
		}
		return sprites[index];
	}

	static function showCommand(sprite:Sprite, command:DrawCommand) {
		var pixiTexture = command.texture.pixiTexture;
		if (sprite.texture.baseTexture != pixiTexture)
			sprite.texture = new Texture(pixiTexture);
		var cut = sprite.texture.frame;
		if (cut.x != command.cutX || cut.y != command.cutY || cut.width != command.cutWidth || cut.height != command.cutHeight)
			sprite.texture.frame = new Rectangle(command.cutX, command.cutY, command.cutWidth, command.cutHeight);
		sprite.transform.setFromMatrix(new Matrix(command.a, command.b, command.c, command.d, command.tx, command.ty));
		sprite.alpha = command.alpha;
		sprite.blendMode = cast pixiBlendModeOf(command.blendMode);
		showColor(sprite, command.colorMatrix);
		sprite.visible = true;
	}
}
