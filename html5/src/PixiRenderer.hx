import h2d.RenderContext.DrawCommand;
import pixi.core.display.Container;
import pixi.core.math.Matrix;
import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;

/**
 * Shows the h2d layer's draw commands with PixiJS: one PixiJS sprite per command, in drawing order.
 * @spec html5.h2d::tile-drawn-at-its-place
 */
class PixiRenderer {
	// PixiJS has no SoftAdd nor SoftOverlay: they get ids of their own, past PixiJS's.
	static inline var SOFT_ADD = 100;
	static inline var SOFT_OVERLAY = 101;
	static inline var WHITE = 0xFFFFFF;
	static inline var DEFAULT_BATCH = "batch";
	// Where PixiJS's 5 x 4 color matrix keeps each channel's own factor.
	static inline var RED_FACTOR = 0;
	static inline var GREEN_FACTOR = 6;
	static inline var BLUE_FACTOR = 12;
	static inline var ALPHA_FACTOR = 18;

	public var root(default, null):Container;
	var sprites:Array<Sprite>;

	public function new(pixiRenderer:Dynamic) {
		root = new Container();
		sprites = [];
		addBlendModesMissingFromPixi(pixiRenderer);
		prepareShaders(pixiRenderer);
	}

	/**
	 * @spec html5.h2d::shaders-ready-before-play: the first picture that uses a shader links it, up to 378 ms frozen.
	 * Each way this renderer draws is drawn once, off the page: the batch, the color plugin, a masked sprite.
	 */
	static function prepareShaders(pixiRenderer:Dynamic) {
		var cases = new Container();
		var batched = new Sprite(Texture.WHITE);
		cases.addChild(batched);
		var colored = new Sprite(Texture.WHITE);
		colored.pluginName = ColorMatrixBatch.PLUGIN;
		untyped colored.colorMatrix = [for (index in 0...20) index % 6 == 0 ? 1.0 : 0.0];
		cases.addChild(colored);
		var masked = new Sprite(Texture.WHITE);
		var mask = new Sprite(Texture.WHITE);
		masked.mask = mask;
		cases.addChild(mask);
		cases.addChild(masked);
		var target = pixi.core.textures.RenderTexture.create(1, 1);
		pixiRenderer.render(cases, target);
		target.destroy(true);
		cases.destroy({children: true});
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
	 * @spec html5.h2d.color::color-like-fork-shader: the fork's color, as one matrix on straight colors.
	 * @spec html5.h2d.color::multiplied-color-as-tint: a color that only multiplies is PixiJS's tint and alpha.
	 * @spec html5.h2d.color::color-matrix-in-batch: any other goes into the batch shader, not into a filter,
	 * which would cost two render target switches per sprite.
	 */
	static function showColor(sprite:Sprite, colorMatrix:Array<Float>) {
		sprite.tint = WHITE;
		sprite.pluginName = DEFAULT_BATCH;
		if (colorMatrix == null)
			return;
		if (onlyMultiplies(colorMatrix)) {
			sprite.tint = channelOf(colorMatrix[RED_FACTOR]) << 16 | channelOf(colorMatrix[GREEN_FACTOR]) << 8 | channelOf(colorMatrix[BLUE_FACTOR]);
			sprite.alpha = colorMatrix[ALPHA_FACTOR];
			return;
		}
		sprite.pluginName = ColorMatrixBatch.PLUGIN;
		untyped sprite.colorMatrix = colorMatrix;
	}

	/** In PixiJS's 5 x 4 matrix, each output's factor of the same input is on the diagonal: every 6th number. */
	static function onlyMultiplies(colorMatrix:Array<Float>):Bool {
		for (index in 0...colorMatrix.length) {
			var factor = colorMatrix[index];
			var onDiagonal = index % 6 == 0;
			if (onDiagonal ? factor < 0 || factor > 1 : factor != 0)
				return false;
		}
		return true;
	}

	static function channelOf(factor:Float):Int {
		return Math.round(factor * 255);
	}

	/**
	 * @spec html5.h2d.color::alpha-map: a PixiJS sprite mask multiplies by its picture's red times its alpha,
	 * which is the fork's red for an opaque mask. The mask sprite lies exactly over the drawn sprite.
	 */
	function showAlphaMap(sprite:Sprite, command:DrawCommand) {
		var mask:Sprite = untyped sprite.__alphaMap;
		if (command.alphaMap == null) {
			if (sprite.mask != null) sprite.mask = null;
			if (mask != null) mask.visible = false;
			return;
		}
		if (mask == null) {
			mask = new Sprite(Texture.EMPTY);
			untyped sprite.__alphaMap = mask;
			root.addChild(mask);
		}
		var map = command.alphaMap;
		if (mask.texture.baseTexture != map.texture.pixiTexture)
			mask.texture = new Texture(map.texture.pixiTexture);
		mask.texture.frame = new Rectangle(map.cutX, map.cutY, map.cutWidth, map.cutHeight);
		// The mask's picture is stretched over the drawn cut, like the fork's alphaMap UVs.
		mask.transform.setFromMatrix(new Matrix(command.a * command.cutWidth / map.cutWidth, command.b * command.cutWidth / map.cutWidth,
			command.c * command.cutHeight / map.cutHeight, command.d * command.cutHeight / map.cutHeight, command.tx, command.ty));
		mask.visible = true;
		sprite.mask = mask;
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

	function showCommand(sprite:Sprite, command:DrawCommand) {
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
		showAlphaMap(sprite, command);
		sprite.visible = true;
	}
}
