import js.Browser;
import js.lib.Promise;

/**
 * The JS build's entry point, in place of the Flash build's WebMain: preloads every asset into AssetStore
 * (the Flash build embedded them in the SWF), keeps the progress in localStorage, then starts the game's Main.
 * @spec html5.boot::everything-preloaded
 */
class GameMain {
	static inline var ASSETS = "assets/";
	static inline var SOUNDS = "../sfx/";
	static var FONTS = [
		{id: "assets/BenchNine-Regular.ttf", family: "BenchNine"},
		{id: "assets/Mouse_Deco.ttf", family: "Mouse Deco"},
	];

	static function main() {
		mt.audio.Audio.backend = new mt.audio.WebAudioBackend(); // the sounds are decoded while preloading
		var loading = new LoadingBar(AssetManifest.IMAGES.length + AssetManifest.TEXTS.length + FONTS.length + AssetManifest.SOUNDS.length);
		var preloads:Array<Promise<Dynamic>> = [];
		for (image in AssetManifest.IMAGES)
			preloads.push(loading.count(preloadImage(image.id, image.keepPixels)));
		for (text in AssetManifest.TEXTS)
			preloads.push(loading.count(preloadText(text)));
		for (font in FONTS)
			preloads.push(loading.count(hxd.res.FontBuilder.load(font.family, ASSETS + font.id).then(function(_) {
				AssetStore.addFont(font.id, font.family);
				return null;
			})));
		for (sound in AssetManifest.SOUNDS)
			preloads.push(loading.count(mt.audio.Sound.preload(sound, SOUNDS + sound)));
		Promise.all(preloads).then(function(_) {
			loading.remove();
			Protocol.useProgressStore(new progress.LocalStorageProgressStore());
			new Main();
		}).catchError(function(error) loading.fail(error));
	}

	static function preloadImage(id:String, keepPixels:Bool):Promise<Dynamic> {
		return new Promise(function(resolve, reject) {
			var picture = new js.html.Image();
			picture.onload = function() {
				var texture = h3d.mat.Texture.fromImage(picture);
				AssetStore.addTexture(id, texture, keepPixels ? pixelsOf(picture) : null);
				resolve(null);
			};
			picture.onerror = function() reject('$id could not be loaded');
			picture.src = ASSETS + id;
		});
	}

	/** The RGBA bytes, for the images the game reads back (ButtonLevel). */
	static function pixelsOf(picture:js.html.Image):Array<Int> {
		var canvas = Browser.document.createCanvasElement();
		canvas.width = picture.width;
		canvas.height = picture.height;
		var context = canvas.getContext2d();
		context.drawImage(picture, 0, 0);
		return cast js.lib.Uint8Array.from(cast context.getImageData(0, 0, picture.width, picture.height).data);
	}

	static function preloadText(id:String):Promise<Dynamic> {
		return Browser.window.fetch(ASSETS + id).then(function(response) {
			if (!response.ok)
				throw '$id could not be loaded (HTTP ${response.status})';
			return response.text();
		}).then(function(text) {
			AssetStore.addText(id, text);
			return null;
		});
	}
}

/** @spec html5::simple-loading-screen: a bar of how many assets are loaded; an asset that fails is named. */
private class LoadingBar {
	var total:Int;
	var loaded = 0;
	var element:js.html.Element;

	public function new(total:Int) {
		this.total = total;
		element = Browser.document.createElement("div");
		element.className = "loading";
		element.innerHTML = '<progress max="$total" value="0"></progress><p>Chargement…</p>';
		Browser.document.body.appendChild(element);
	}

	public function count(preload:Promise<Dynamic>):Promise<Dynamic> {
		return preload.then(function(result) {
			loaded++;
			(cast element.querySelector("progress")).value = loaded;
			return result;
		});
	}

	public function remove() {
		element.remove();
	}

	public function fail(error:Dynamic) {
		element.querySelector("p").textContent = Std.string(error);
		element.className = "loading error";
		Browser.console.error(error);
	}
}
