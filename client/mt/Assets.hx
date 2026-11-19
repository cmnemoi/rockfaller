package mt;

class Assets {
    public static var USE_HALF_SIZE:Bool = false;
    public static var USE_CACHE:Bool = true;

    /**
     * forceRetain keeps the image as BitmapData next to the GPU texture, like
     * Motion-Twin's version: ButtonLevel.SET_POS reads the map's red markers in it.
     */
    public static function getTile(path:String, ?forceRetain:Bool = false):Void->h2d.Tile {
        return function() {
            var image = hxd.Res.load(path).toImage();
            var tile = image.toTile();
            if (forceRetain)
                tile.getTexture().bmp = image.toBitmap();
            return tile;
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

class PVRTexture extends h3d.mat.Texture {
    public function reallocMT():Dynamic {
        realloc();
        return null;
    }
}
