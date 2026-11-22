package h2d;

/** Replaces the fork's GPU Scene: the root of the tree, which syncs then draws it into a RenderContext. */
class Scene extends Sprite {
	public function new() {
		super(null);
	}

	public function render(ctx:RenderContext) {
		ctx.startFrame();
		sync(ctx);
		drawRec(ctx);
	}
}
