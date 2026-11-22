import js.Browser;
import js.html.Image;
import js.lib.Promise;
import mt.deepnight.slb.assets.TexturePackerXml;
import mt.deepnight.slb.assets.TexturePackerXml.TexturePackerSlice;
import pixi.core.Application;
import pixi.core.Pixi.MipmapModes;
import pixi.core.math.shapes.Rectangle;
import pixi.core.sprites.Sprite;
import pixi.core.textures.BaseTexture;
import pixi.core.textures.Texture;

/**
 * Entry point of the PixiJS page (/pixi/): shows one sprite of an atlas, to prove the whole chain works.
 * @spec html5.pixi-page::shows-atlas-sprite
 */
class Main {
	static inline var GAME_WIDTH = 640;
	static inline var GAME_HEIGHT = 768;
	static inline var ATLAS_XML = "assets1.xml";
	static inline var ATLAS_PICTURE = "assets1.png";
	static inline var SPRITE = "animalDuck";

	static function main() {
		var app = new Application({width: GAME_WIDTH, height: GAME_HEIGHT, backgroundColor: 0x000000});
		Browser.document.body.appendChild(app.view);
		#if debug
		untyped Browser.window.pixiApp = app; // lets browser checks reach the stage
		#end

		loadText(ATLAS_XML).then(function(xml) {
			return loadPicture(ATLAS_PICTURE).then(function(picture) {
				var atlas = TexturePackerXml.read(xml, false);
				var sprite = new Sprite(textureOf(atlasTexture(picture), atlas.find(SPRITE)));
				sprite.x = (GAME_WIDTH - sprite.width) / 2;
				sprite.y = (GAME_HEIGHT - sprite.height) / 2;
				app.stage.addChild(sprite);
			});
		}).catchError(showError);
	}

	/** @spec html5::atlas-no-bleeding: PixiJS 6 gives a 2048 px texture mipmaps, which bleed into the neighbours. */
	static function atlasTexture(picture:Image):BaseTexture {
		var texture = BaseTexture.from(picture);
		texture.mipmap = MipmapModes.OFF;
		return texture;
	}

	/** @spec html5.atlas::trimmed-sprite-keeps-frame */
	static function textureOf(atlasTexture:BaseTexture, slice:TexturePackerSlice):Texture {
		var cut = new Rectangle(slice.x, slice.y, slice.wid, slice.hei);
		var frame = new Rectangle(0, 0, slice.fwid, slice.fhei);
		var placeInFrame = new Rectangle(-slice.offX, -slice.offY, slice.wid, slice.hei);
		return new Texture(atlasTexture, cut, frame, placeInFrame);
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
