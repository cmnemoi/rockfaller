package h3d;

/** The fork's GPU memory manager. PixiJS manages its own textures: these calls have nothing to do here. */
class MemoryManager {
	public function new() {}
	public function startTextureGC(?frames:Int) {}
	public function cleanBuffers() {}
}

class Driver {
	public function new() {}
	/** The game reports a software renderer to its server (DataManager); WebGL is hardware. */
	public function isHardware() return true;
}

/**
 * Replaces the fork's Stage3D engine: init() makes the PixiJS renderer and its canvas, then calls onReady;
 * render(scene) draws the scene's commands with PixiRenderer. The game uses it like the fork's (Main).
 */
class Engine {
	static var CURRENT:Engine;
	static inline var INTERACTION_PLUGIN = "interaction";

	public var width(default, null):Int;
	public var height(default, null):Int;
	public var mem(default, null):MemoryManager;
	public var driver(default, null):Driver;
	public dynamic function onReady() {}
	public dynamic function onResized() {}

	#if pixijs
	public var pixiRenderer(default, null):pixi.core.renderers.webgl.Renderer;
	public var renderer(default, null):PixiRenderer;
	#end
	var context:h2d.RenderContext;

	public function new() {
		width = hxd.System.width;
		height = hxd.System.height;
		mem = new MemoryManager();
		driver = new Driver();
		context = new h2d.RenderContext();
		CURRENT = this;
	}

	public static function getCurrent():Engine {
		return CURRENT;
	}

	/** Makes the canvas and calls onReady, as the fork does once its Stage3D context exists. */
	public function init() {
		#if pixijs
		ColorMatrixBatch.register();
		var options:Dynamic = {width: width, height: height, backgroundColor: 0x000000, useContextAlpha: false};
		pixiRenderer = new pixi.core.renderers.webgl.Renderer(options);
		applyRendererSettings(pixiRenderer);
		renderer = new PixiRenderer(pixiRenderer);
		js.Browser.document.body.appendChild(pixiRenderer.view);
		hxd.Stage.getInstance().attachTo(pixiRenderer.view);
		if (mt.audio.Audio.backend == null) // GameMain makes it first, to decode the sounds it preloads
			mt.audio.Audio.backend = new mt.audio.WebAudioBackend();
		#end
		onReady();
	}

	#if pixijs
	/**
	 * @spec html5.h2d::renderer-settings: hxd.Stage handles the pointer, so PixiJS's interaction manager, its second
	 * animation frame loop and its hit tests go; textures stay on the GPU, like the Flash build's NoTextureGC.
	 */
	static function applyRendererSettings(pixiRenderer:Dynamic) {
		var plugins:haxe.DynamicAccess<Dynamic> = pixiRenderer.plugins;
		if (plugins.exists(INTERACTION_PLUGIN)) {
			plugins.get(INTERACTION_PLUGIN).destroy();
			plugins.remove(INTERACTION_PLUGIN);
		}
		pixiRenderer.textureGC.mode = untyped PIXI.GC_MODES.MANUAL;
	}
	#end

	public function render(scene:h2d.Scene) {
		scene.render(context);
		#if pixijs
		renderer.show(context.drawn);
		pixiRenderer.render(renderer.root);
		#end
	}

	/** The fork gives the stage back to OpenFL after drawing; there is no OpenFL here. */
	public function restoreOpenfl() {}

	/** The last frame's draw commands, for the browser checks. */
	public function lastDrawn():Array<h2d.RenderContext.DrawCommand> {
		return context.drawn;
	}
}
