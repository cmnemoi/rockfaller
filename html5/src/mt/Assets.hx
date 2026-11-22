package mt;

/**
 * The JS build's mt.Assets: tiles of preloaded images. In Flash, hxd.Res reads embedded images instead.
 * forceRetain keeps the image's pixels next to the texture: ButtonLevel.SET_POS reads the map's red markers in them.
 */
class Assets {
	public static var USE_HALF_SIZE:Bool = false;
	public static var USE_CACHE:Bool = true;

	public static function getTile(path:String, ?forceRetain:Bool = false):Void->h2d.Tile {
		return function() {
			var texture = AssetStore.texture(path);
			if (forceRetain)
				texture.bmp = new h3d.mat.Texture.TexturePixels(texture.width, AssetStore.pixels(path));
			return h2d.Tile.fromTexture(texture);
		};
	}

	public static function getTileDeferred(path:String, worker:Worker, callback:h2d.Tile->Void):Void {
		var tile:Null<h2d.Tile> = null;
		var task = new mt.Worker.WorkerTask(function() {
			tile = getTile(path)();
		});
		task.onComplete = function() {
			if (callback != null && tile != null) {
				callback(tile);
			}
		};

		if (worker != null) {
			worker.enqueue(task);
		} else {
			task.execute();
		}
	}
}

/** Flash-only (compressed GPU textures); SubLoader asks whether a texture is one. */
class PVRTexture extends h3d.mat.Texture {
	public function reallocMT():Dynamic {
		return null;
	}
}
