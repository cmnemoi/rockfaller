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
	public var root(default, null):Container;
	var sprites:Array<Sprite>;

	public function new() {
		root = new Container();
		sprites = [];
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
		sprite.visible = true;
	}
}
