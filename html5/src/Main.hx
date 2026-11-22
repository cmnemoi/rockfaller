import h2d.RenderContext;
import h2d.Scene;
import js.Browser;
import js.html.Image;
import js.lib.Promise;
import mt.deepnight.slb.BLib;
import mt.deepnight.slb.assets.TexturePacker;
import pixi.core.Application;
import pixi.core.Pixi.MipmapModes;
import pixi.core.textures.BaseTexture;

/**
 * Entry point of the PixiJS page (/pixi/): the game's own SpriteLib, drawn by the h2d layer on PixiJS.
 * @spec html5.slb::page-plays-grip-anim
 */
class Main {
	static inline var GAME_WIDTH = 640;
	static inline var GAME_HEIGHT = 768;
	static inline var UPDATES_PER_SECOND = 30;
	static inline var MAX_FRAME_MS = 100;

	static function main() {
		var app = new Application({width: GAME_WIDTH, height: GAME_HEIGHT, backgroundColor: 0x000000});
		Browser.document.body.appendChild(app.view);
		var scene = new Scene();
		var renderer = new PixiRenderer();
		app.stage.addChild(renderer.root);

		Promise.all([loadLib("assets1", false), loadLib("taupinotron", true)]).then(function(libs:Array<BLib>) {
			var items = libs[0];
			var taupinotron = libs[1];
			var duck = items.h_get("animalDuck", 0.5, 0.5, scene);
			duck.setPos(GAME_WIDTH / 4, GAME_HEIGHT / 2);
			var grip = taupinotron.h_get("gripAnim", 0.5, 0.5, scene);
			grip.setPos(GAME_WIDTH / 2, GAME_HEIGHT / 2);
			grip.a.playAndLoop("gripAnim");

			var context = new RenderContext();
			var elapsedMs = 0.0;
			app.ticker.add(function(_) {
				// Like PixiJS's deltaMS (missing from the externs): a frame counts for 100 ms at most, so a hidden tab does not fast-forward.
				elapsedMs += Math.min(app.ticker.elapsedMS, MAX_FRAME_MS);
				while (elapsedMs >= 1000 / UPDATES_PER_SECOND) {
					elapsedMs -= 1000 / UPDATES_PER_SECOND;
					taupinotron.updateChildren();
				}
				scene.render(context);
				renderer.show(context.drawn);
			});

			#if debug
			untyped Browser.window.rockfallerDebug = {app: app, scene: scene, renderer: renderer, context: context, grip: grip, duck: duck};
			#end
		}).catchError(showError);
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
