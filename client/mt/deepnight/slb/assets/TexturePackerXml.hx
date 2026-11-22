package mt.deepnight.slb.assets;

/**
 * Reads the slices of a TexturePacker XML atlas, without any picture or display engine,
 * so the Flash build (through TexturePacker.parseXml) and the JS build share the same naming rules.
 * Compiles with Haxe 3.2.1 and Haxe 4.
 * @spec html5.atlas::one-reader-for-both-builds
 */
class TexturePackerXml {
	public static function read(xmlString:String, treatFoldersAsPrefixes:Bool):TexturePackerAtlas {
		var atlas = new TexturePackerAtlas();
		var removeExt = ~/\.(png|gif|jpeg|jpg)/gi;
		var leadNumber = ~/([0-9]*)$/;
		var frameByChecksum : Map<String, Int> = new Map();
		for(textureAtlas in Xml.parse(xmlString).elementsNamed("TextureAtlas")) {
			var last : TexturePackerSlice = null;
			var frame = 0;
			for(sub in textureAtlas.elementsNamed("SubTexture")) {
				var rawName = sub.get("name");
				var slice : TexturePackerSlice = {
					name	: rawName,
					frame	: 0,
					x		: Std.parseInt(sub.get("x")),
					y		: Std.parseInt(sub.get("y")),
					wid		: Std.parseInt(sub.get("width")),
					hei		: Std.parseInt(sub.get("height")),
					offX	: !sub.exists("frameX") ? 0 : Std.parseInt(sub.get("frameX")),
					offY	: !sub.exists("frameY") ? 0 : Std.parseInt(sub.get("frameY")),
					fwid	: !sub.exists("frameWidth") ? Std.parseInt(sub.get("width")) : Std.parseInt(sub.get("frameWidth")),
					fhei	: !sub.exists("frameHeight") ? Std.parseInt(sub.get("height")) : Std.parseInt(sub.get("frameHeight")),
				}

				slice.name = removeExt.replace(rawName, "");
				if( slice.name.indexOf("/")>=0 )
					if( treatFoldersAsPrefixes )
						slice.name = StringTools.replace(slice.name, "/", "_");
					else
						slice.name = slice.name.substr(slice.name.lastIndexOf("/")+1);

				// Remove the trailing number, then the trailing "_" (only "_": "mudPartSmall-24" gives "mudPartSmall-")
				if( leadNumber.match(slice.name) ) {
					slice.name = slice.name.substr(0, leadNumber.matchedPos().pos);
					while( slice.name.length>0 && slice.name.charAt(slice.name.length-1)=="_" )
						slice.name = slice.name.substr(0, slice.name.length-1);
				}

				// A new name starts a new animation
				if( last == null || last.name != slice.name)
					frame = 0;

				var checksum = makeChecksum(slice);
				if( !frameByChecksum.exists(checksum) ) {
					frameByChecksum.set(checksum, frame);
					slice.frame = frame;
					atlas.add(slice, rawName);
					frame++;
				}
				atlas.addAnimationFrame(slice.name, frameByChecksum.get(checksum));

				last = slice;
			}
		}
		return atlas;
	}

	static inline function makeChecksum(slice:TexturePackerSlice) : String {
		return slice.name+","+slice.x+","+slice.y+","+slice.wid+","+slice.hei+","+slice.offX+","+slice.offY+","+slice.fwid+","+slice.fhei;
	}
}

typedef TexturePackerSlice = {
	var name	: String;
	var frame	: Int;
	var x		: Int;
	var y		: Int;
	var wid		: Int;
	var hei		: Int;
	var offX	: Int;
	var offY	: Int;
	var fwid	: Int;
	var fhei	: Int;
}

class TexturePackerAtlas {
	/** Each distinct picture once, in the order of the XML. */
	public var slices(default, null) : Array<{slice:TexturePackerSlice, rawName:String}>;
	/** The frames each name plays, in the order of the XML: an identical picture repeats its frame. */
	public var animations(default, null) : Map<String, Array<Int>>;
	var sliceByKey : Map<String, TexturePackerSlice>;

	public function new() {
		slices = [];
		animations = new Map();
		sliceByKey = new Map();
	}

	public function exists(name:String, ?frame = 0) : Bool {
		return sliceByKey.exists(key(name, frame));
	}

	/** Same message as BLib.getTile. */
	public function find(name:String, ?frame = 0) : TexturePackerSlice {
		if( !exists(name, frame) )
			throw 'Unknown group $name#$frame!';
		return sliceByKey.get(key(name, frame));
	}

	public function add(slice:TexturePackerSlice, rawName:String) {
		slices.push({slice:slice, rawName:rawName});
		sliceByKey.set(key(slice.name, slice.frame), slice);
		sliceByKey.set(key(rawName, 0), slice);
	}

	public function addAnimationFrame(name:String, frame:Int) {
		if( !animations.exists(name) )
			animations.set(name, [frame]);
		else
			animations.get(name).push(frame);
	}

	static inline function key(name:String, frame:Int) : String {
		return name + "#" + frame;
	}
}
