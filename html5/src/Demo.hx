import h2d.RenderContext;
import h2d.Scene;
import js.Browser;
import js.html.Image;
import js.lib.Promise;
import mt.deepnight.slb.BLib;
import mt.deepnight.slb.assets.TexturePacker;
import hxd.res.FontBuilder;
import pixi.core.Pixi.MipmapModes;
import pixi.core.textures.BaseTexture;

/**
 * Entry point of the PixiJS page (/pixi/): the game's own SpriteLib, drawn by the h2d layer on PixiJS.
 * @spec html5.slb::page-plays-grip-anim
 */
class Demo {
	static inline var GAME_WIDTH = 640;
	static inline var GAME_HEIGHT = 768;
	static inline var TITLE_FONT = "BenchNine";
	static inline var TITLE_FONT_URL = "../font/BenchNine-Regular.ttf";
	static inline var TITLE_SIZE = 44;
	static inline var DUCK_FRAME = 98;
	static inline var DUCK_SOUND = "rocks_mouseover2.mp3";
	// The colour bench, in the empty bottom of the page.
	static inline var BENCH_X = 20;
	static inline var BENCH_Y = 620;
	static inline var BENCH_SQUARE = 20;
	static inline var BENCH_TEXT_SIZE = 60;

	static function main() {
		var engine = new h3d.Engine();
		engine.onReady = function() {
			var scene = new Scene();
			Promise.all([loadLib("assets1", false), loadLib("taupinotron", true), FontBuilder.load(TITLE_FONT, TITLE_FONT_URL), mt.audio.Sound.preload(DUCK_SOUND, "../sfx/" + DUCK_SOUND)]).then(function(loaded:Array<Dynamic>) {
				var libs:Array<BLib> = cast loaded;
				var items = libs[0];
				var taupinotron = libs[1];
				var duck = items.h_get("animalDuck", 0.5, 0.5, scene);
				duck.setPos(GAME_WIDTH / 4, GAME_HEIGHT / 2);
				var grip = taupinotron.h_get("gripAnim", 0.5, 0.5, scene);
				grip.setPos(GAME_WIDTH / 2, GAME_HEIGHT / 2);
				grip.a.playAndLoop("gripAnim");
				var title = new h2d.Text(FontBuilder.getFont(TITLE_FONT, TITLE_SIZE, {antiAliasing: false}), scene);
				title.text = "Rockfaller Journey : \u00E9t\u00E9";
				title.setPos(20, 40);
				// Clicking the duck turns it: the Interactive covers its 98 x 98 frame, centred on it.
				var duckButton = new h2d.Interactive(DUCK_FRAME, DUCK_FRAME, scene);
				duckButton.setPos(duck.x - DUCK_FRAME / 2, duck.y - DUCK_FRAME / 2);
				var duckClicks = 0;
				duckButton.onClick = function(_) {
					duckClicks++;
					duck.rotation += Math.PI / 8;
					new mt.flash.Sfx(mt.flash.Sfx.getAsset(DUCK_SOUND)).play();
				};

				// The game's Main loop: the timer counts Flash frames (30 per second), each one is an update.
				var flashFrames = 0.0;
				hxd.System.setLoop(function() {
					hxd.Timer.update();
					flashFrames += hxd.Timer.tmod;
					while (flashFrames >= 1) {
						taupinotron.updateChildren();
						scene.checkEvents(); // what the game's Process.updateAll does
						flashFrames--;
					}
					engine.render(scene);
				});

				#if debug
				var app = {
					view: engine.pixiRenderer.view,
					renderer: engine.pixiRenderer,
					render: function() engine.render(scene),
				};
				// The tutorial's spotlight, for the browser checks: a veil at 0.75, its mask white but for a black square over the duck.
				var spotlight = function(holeOverDuck:Bool) {
					var veil = new h2d.Bitmap(h2d.Tile.fromColor(0xFF000000, GAME_WIDTH, GAME_HEIGHT), scene);
					veil.alpha = 0.75;
					var canvas = Browser.document.createCanvasElement();
					canvas.width = GAME_WIDTH;
					canvas.height = GAME_HEIGHT;
					var context = canvas.getContext2d();
					context.fillStyle = "#FFFFFF";
					context.fillRect(0, 0, GAME_WIDTH, GAME_HEIGHT);
					if (holeOverDuck) {
						context.fillStyle = "#000000";
						context.fillRect(duck.x - DUCK_FRAME / 2, duck.y - DUCK_FRAME / 2, DUCK_FRAME, DUCK_FRAME);
					}
					veil.alphaMap = h2d.Tile.fromTexture(h3d.mat.Texture.fromCanvas(canvas));
				};
				// The colour bench, for the parity checks of the colours: white squares and a text, each coloured its way, over black.
				var colorBench = function() {
					var white = h2d.Tile.fromColor(0xFFFFFFFF, BENCH_SQUARE, BENCH_SQUARE);
					var square = function(index:Int) {
						var bitmap = new h2d.Bitmap(white, scene);
						bitmap.setPos(BENCH_X + index * 2 * BENCH_SQUARE, BENCH_Y);
						return bitmap;
					};
					var halfRed = square(0);
					halfRed.color = new h3d.Vector(0.5, 1, 1, 1);
					halfRed.alpha = 0.5;
					var alphaByColor = square(1);
					alphaByColor.color = new h3d.Vector(1, 1, 1, 0.5);
					var alphaAlone = square(2);
					alphaAlone.alpha = 0.5;
					var invisibleRed = square(3);
					invisibleRed.color = new h3d.Vector(1, 0, 0, 1);
					invisibleRed.alpha = 0;
					var text = new h2d.Text(FontBuilder.getFont(TITLE_FONT, BENCH_TEXT_SIZE, {antiAliasing: false}), scene);
					text.textColor = 0x804020;
					text.text = "IIII";
					text.setPos(BENCH_X, BENCH_Y + 2 * BENCH_SQUARE);
					return {square: BENCH_SQUARE, x: BENCH_X, y: BENCH_Y, textY: BENCH_Y + 2 * BENCH_SQUARE, textHeight: text.textHeight};
				};
				untyped Browser.window.rockfallerDebug = {colorBench: colorBench, spotlight: spotlight, app: app, scene: scene, renderer: engine.renderer, context: @:privateAccess engine.context, grip: grip, duck: duck, title: title, duckClicks: function() return duckClicks, BlendMode: h2d.BlendMode, Vector: h3d.Vector, FontBuilder: FontBuilder, audio: mt.audio.Audio.backend};
				#end
			}).catchError(showError);
		};
		engine.init();
	}

	static function loadLib(atlas:String, treatFoldersAsPrefixes:Bool):Promise<BLib> {
		return loadText(atlas + ".xml").then(function(xml) {
			return loadPicture(atlas + ".png").then(function(picture) {
				var tile = h2d.Tile.fromTexture(h3d.mat.Texture.fromPixi(atlasTexture(picture)));
				return TexturePacker.parseXml(xml, null, treatFoldersAsPrefixes, tile);
			});
		});
	}

	/** @spec html5::atlas-no-bleeding: PixiJS 6 gives a 2048 px texture mipmaps, which bleed into the neighbours. */
	static function atlasTexture(picture:Image):BaseTexture {
		var texture = BaseTexture.from(picture);
		texture.mipmap = MipmapModes.OFF;
		return texture;
	}

	static function loadText(url:String):Promise<String> {
		return Browser.window.fetch(url).then(function(response) {
			if (!response.ok)
				throw '$url could not be loaded (HTTP ${response.status})';
			return response.text();
		});
	}

	static function loadPicture(url:String):Promise<Image> {
		return new Promise(function(resolve, reject) {
			var picture = new Image();
			picture.onload = function() resolve(picture);
			picture.onerror = function() reject('$url could not be loaded');
			picture.src = url;
		});
	}

	/** @spec html5.pixi-page::atlas-load-error-visible */
	static function showError(error:Dynamic) {
		var message = Browser.document.createParagraphElement();
		message.className = "error";
		message.textContent = Std.string(error);
		Browser.document.body.appendChild(message);
		Browser.console.error(error);
	}
}
