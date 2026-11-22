#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * The game's assets, listed at compile time from the classpath's assetsWeb and sfx folders, with the ids the game
 * asks for (paths inside assetsWeb, sound file names). The loading screen preloads them all into AssetStore.
 * @spec html5.boot::everything-preloaded
 */
class AssetManifest {
	#if !macro
	/** keepPixels: ButtonLevel reads the level paths' pixels; keeping a 2048 px atlas's pixels costs 16 MB, so only those. */
	public static var IMAGES:Array<{id:String, keepPixels:Bool}> = images();
	public static var TEXTS:Array<String> = texts();
	public static var SOUNDS:Array<String> = sounds();
	#end

	static macro function images():Expr {
		var entries = [for (id in filesIn("assetsWeb", ".png")) macro {id: $v{id}, keepPixels: $v{StringTools.startsWith(id, "levels")}}];
		return macro $a{entries};
	}

	static macro function texts():Expr {
		var found = filesIn("assetsWeb", ".json");
		found.push("data/loot.json"); // OpenFL renamed the repository's data folder to data
		return macro $v{found};
	}

	static macro function sounds():Expr {
		return macro $v{filesIn("sfx", ".mp3")};
	}

	#if macro
	static function filesIn(folder:String, extension:String):Array<String> {
		for (classPath in Context.getClassPath()) {
			var root = haxe.io.Path.addTrailingSlash(classPath) + folder;
			if (sys.FileSystem.exists(root) && sys.FileSystem.isDirectory(root)) {
				var found = [];
				collect(root, "", extension, found);
				found.sort(Reflect.compare);
				return found;
			}
		}
		Context.error('No $folder folder in the classpath', Context.currentPos());
		return null;
	}

	static function collect(root:String, prefix:String, extension:String, found:Array<String>) {
		for (name in sys.FileSystem.readDirectory(root + "/" + prefix)) {
			var id = prefix + name;
			if (sys.FileSystem.isDirectory(root + "/" + id))
				collect(root, id + "/", extension, found);
			else if (StringTools.endsWith(name, extension))
				found.push(id);
		}
	}
	#end
}
