package mt.deepnight.slb.assets;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;

#else

import mt.deepnight.slb.BLib;

#end

class TexturePacker {

	/**
	 * Import the specified TexturePacker data using OpenFl Assets
	 *
	 * @param xmlUrl		You really don't understand this parameter?
	 * @param ?treatFoldersAsPrefixes	If TRUE, folder names in sub-texture names will be used as part of the identifier. If FALSE, the folder names are just discarded.
	 */
	public static macro function importXmlOpenFl(xmlUrl:String, ?treatFoldersAsPrefixes:Bool=false) {
		var p = Context.currentPos();

		xmlUrl = StringTools.replace(xmlUrl, "\\", "/");
		var basePath = ( xmlUrl.indexOf("/") >= 0 ? xmlUrl.substr(0, xmlUrl.lastIndexOf("/")) : "" ) ;
		if ( basePath.length > 0 )
			basePath += "/";
		var id = AssetTools.cleanUpString(xmlUrl);

		// XML parsing
		var file = try Context.resolvePath(xmlUrl) catch( e : Dynamic ) { AssetTools.error("TexturePacker XML not found: "+xmlUrl, p); null; }
		var xml = new haxe.xml.Fast( Xml.parse(sys.io.File.getContent(file)) );
		Context.addResource("_XML_"+id, sys.io.File.getBytes(file));

		// Bitmap source declaration
		var imgName = xml.node.TextureAtlas.att.imagePath;
		var imgUrl = basePath + imgName;
		try Context.resolvePath(imgUrl) catch( e : Dynamic ) { AssetTools.error("TexturePacker image not found: "+imgUrl, p); null; }

		Context.registerModuleDependency(Context.getLocalModule(), Context.resolvePath(xmlUrl));
		Context.registerModuleDependency(Context.getLocalModule(), Context.resolvePath(imgUrl));

		// New lib declaration
		var blockContent : Array<Expr> = [];
		var folderFlagExpr = Context.makeExpr(treatFoldersAsPrefixes, p);
		var rscIdExper = Context.makeExpr("_XML_"+id, p);
		var rscGetter = macro haxe.Resource.getString($rscIdExper);
		var imgUrlExpr = { pos:p, expr:EConst(CString(imgUrl)) }
		var newImgExpr = macro openfl.Assets.getBitmapData($imgUrlExpr,true);
		blockContent.push( macro var _lib = mt.deepnight.slb.assets.TexturePacker.parseXml($rscGetter, $newImgExpr, $folderFlagExpr) );
		blockContent.push( macro _lib );

		return { pos:p, expr:EBlock(blockContent) }
	}
	
	#if h3d
	/**
	 * Import the specified TexturePacker data using Mt Assets
	 *
	 * @param xmlUrl		You really don't understand this parameter?
	 * @param ?treatFoldersAsPrefixes	If TRUE, folder names in sub-texture names will be used as part of the identifier. If FALSE, the folder names are just discarded.
	 */
	public static macro function importXmlMt(xmlUrl:String, ?treatFoldersAsPrefixes:Bool=false, ?texPath:String, ?defer:Bool=false, ?forceRetainTex:Bool=false ) {
		var p = Context.currentPos();

		xmlUrl = StringTools.replace(xmlUrl, "\\", "/");
		var basePath = ( xmlUrl.indexOf("/")>=0 ? xmlUrl.substr(0, xmlUrl.lastIndexOf("/")) : "" );
		if ( basePath.length > 0 )
			basePath += "/";
		var id = AssetTools.cleanUpString(xmlUrl);

		// XML parsing
		var file = try Context.resolvePath(xmlUrl) catch( e : Dynamic ) { AssetTools.error("TexturePacker XML not found: "+xmlUrl, p); null; }
		var xml = new haxe.xml.Fast( Xml.parse(sys.io.File.getContent(file)) );
		Context.addResource("_XML_"+id, sys.io.File.getBytes(file));

		// Bitmap source declaration
		var imgName = xml.node.TextureAtlas.att.imagePath;
		var imgUrl = basePath + imgName;
		//try Context.resolvePath(imgUrl) catch( e : Dynamic ) { AssetTools.error("TexturePacker image not found: "+imgUrl, p); null; }

		Context.registerModuleDependency(Context.getLocalModule(), Context.resolvePath(xmlUrl));
		//Context.registerModuleDependency(Context.getLocalModule(), Context.resolvePath(imgUrl));

		// New lib declaration
		var blockContent : Array<Expr> = [];
		var folderFlagExpr = Context.makeExpr(treatFoldersAsPrefixes, p);
		var rscIdExper = Context.makeExpr("_XML_"+id, p);
		var rscGetter = macro haxe.Resource.getString($rscIdExper);
		var imgUrlExpr = { pos:p, expr:EConst(CString(texPath==null?imgUrl:texPath)) }
		var forceRetainExpr = Context.makeExpr(forceRetainTex,p);

		if( defer ){
			var newImgExpr = macro mt.Assets.getTile($imgUrlExpr,$forceRetainExpr);

			blockContent.push( macro var _bmp = $newImgExpr );
			blockContent.push( macro var _fun = function() return  mt.deepnight.slb.assets.TexturePacker.parseXml($rscGetter,  null, $folderFlagExpr, _bmp() ) );
			blockContent.push( macro _fun );
		}else{
			var newImgExpr = macro mt.Assets.getTile($imgUrlExpr,$forceRetainExpr)();
			
			blockContent.push( macro var _lib = mt.deepnight.slb.assets.TexturePacker.parseXml($rscGetter,  null, $folderFlagExpr, $newImgExpr ) );
			blockContent.push( macro _lib );
		}
		return { pos:p, expr:EBlock(blockContent) }
	}

	public static macro function importXmlMtDeferred( name:String, worker:ExprOf<mt.Worker>, onComplete:ExprOf<BLib->Void>,?treatFoldersAsPrefixes:Bool=false, ?texPath:String, ?forceRetainTex:Bool=false ){
		var p = Context.currentPos();
		var nameExpr = Context.makeExpr(name,p);
		var treatFoldersAsPrefixesExpr = Context.makeExpr(treatFoldersAsPrefixes,p);
		var texPathExpr = Context.makeExpr(texPath,p);
		var forceRetainTexExpr = Context.makeExpr(forceRetainTex,p);

		return macro {
			var f : Void->BLib;
			var task = $worker.enqueue( new mt.Worker.WorkerTask(function(){
				f = TexturePacker.importXmlMt($nameExpr,$treatFoldersAsPrefixesExpr,$texPathExpr,true,$forceRetainTexExpr) ;
			}));
			task.onComplete = function(){
				$onComplete( f() );
			}
		}
	}


	#end

	/**
	 * Import the specified TexturePacker data using native Haxe Resource system
	 *
	 * @param xmlUrl		You really don't understand this parameter?
	 * @param ?treatFoldersAsPrefixes	If TRUE, folder names in sub-texture names will be used as part of the identifier. If FALSE, the folder names are just discarded.
	 */
	public static macro function importXml(xmlUrl:String, ?treatFoldersAsPrefixes:Bool=false) {
		var p = Context.currentPos();

		xmlUrl = StringTools.replace(xmlUrl, "\\", "/");
		var basePath = ( xmlUrl.indexOf("/")>=0 ? xmlUrl.substr(0, xmlUrl.lastIndexOf("/")) : "" ) + "/";
		var id = AssetTools.cleanUpString(xmlUrl);

		// XML parsing
		var file = try Context.resolvePath(xmlUrl) catch( e : Dynamic ) { AssetTools.error("TexturePacker XML not found: "+xmlUrl, p); null; }
		var xml = new haxe.xml.Fast( Xml.parse(sys.io.File.getContent(file)) );
		Context.addResource("_XML_"+id, sys.io.File.getBytes(file));

		// Bitmap type declaration
		var imgName = xml.node.TextureAtlas.att.imagePath;
		var imgUrl = basePath + imgName;
		try Context.resolvePath(imgUrl) catch( e : Dynamic ) { AssetTools.error("TexturePacker image not found: "+imgUrl, p); null; }

		var imgType = {
			pos : p,
			pack : [],
			name : "_BITMAP_"+id,
			meta : [{ name : ":bitmap", pos : p, params : [{ expr : EConst(CString(imgUrl)), pos : p }] }],
			params : [],
			isExtern : false,
			fields : [],
			kind : TDClass({ pack : ["flash","display"], name : "BitmapData", params : [] }),
		};

		if( !AssetTools.typeExists("_BITMAP_"+id) )
			Context.defineType(imgType);

		Context.registerModuleDependency(Context.getLocalModule(), Context.resolvePath(xmlUrl));
		Context.registerModuleDependency(Context.getLocalModule(), Context.resolvePath(imgUrl));

		// New lib declaration
		var blockContent : Array<Expr> = [];
		var folderFlagExpr = Context.makeExpr(treatFoldersAsPrefixes, p);
		var rscIdExper = Context.makeExpr("_XML_"+id, p);
		var rscGetter = macro haxe.Resource.getString($rscIdExper);
		var zeroExpr = { expr:EConst(CInt("0")), pos:p }
		var newImgExpr ={ expr : ENew({pack:imgType.pack, name:imgType.name, params:[]}, [zeroExpr,zeroExpr]), pos:p }
		blockContent.push( macro var _lib = mt.deepnight.slb.assets.TexturePacker.parseXml($rscGetter, $newImgExpr, $folderFlagExpr) );
		blockContent.push( macro _lib.initBdGroups() );
		blockContent.push( macro _lib );

		return { pos:p, expr:EBlock(blockContent) }
	}



	#if !macro

	// The JS build has no BitmapData: it gives a tile, and source stays null.
	@:noCompletion public static function parseXml(xmlString:String, source: #if flash flash.display.BitmapData #else Dynamic #end, treatFoldersAsPrefixes:Bool #if h3d, ?tile:h2d.Tile#end) : BLib {
		var lib = new BLib(source #if h3d, tile #end);
		try {
			var atlas = TexturePackerXml.read(xmlString, treatFoldersAsPrefixes);
			for(entry in atlas.slices) {
				var slice = entry.slice;
				var realFrame = {x:slice.offX, y:slice.offY, realWid:slice.fwid, realHei:slice.fhei};
				lib.sliceCustom(slice.name, slice.frame, slice.x, slice.y, slice.wid, slice.hei, realFrame);
				lib.sliceCustom(entry.rawName, 0, slice.x, slice.y, slice.wid, slice.hei, realFrame);
			}
			for(name in atlas.animations.keys())
				lib.__defineAnim(name, atlas.animations.get(name));
		}
		catch(e:Dynamic) {
			throw SLBError.AssetImportFailed(e);
		}

		return lib;
	}
	#end


	#if (flash && !macro)
	public static function downloadXml(xmlUrl:String, imgUrl:String, treatFoldersAsPrefixes:Bool, onComplete:BLib->Void, ?onCustomError:Void->Void = null) {
		var xml : String = null;
		var bd : flash.display.BitmapData = null;
		var steps = 0;
		
		function onError(msg, url) {
			throw SLBError.AssetImportFailed("TexturePacker download failed:"+msg+" "+url);
		}			

		function onOneDone() {
			steps++;
			if( steps>=2 ) {
				var lib = parseXml(xml, bd, treatFoldersAsPrefixes);
				onComplete(lib);
			}
		}

		// Load XML
		var r = new haxe.Http(xmlUrl);
		r.onError = function(msg) {
			if (onCustomError == null)
				onError(msg, xmlUrl);
			else
				onCustomError();
		};
		r.onData = function(data) {
			xml = data;
			onOneDone();
		}
		r.request(true);

		// Load bitmap
		var l = new flash.display.Loader();
		#if flash
		l.contentLoaderInfo.addEventListener( flash.events.IOErrorEvent.NETWORK_ERROR, function(e) onError(e.text, imgUrl) );
		#end
		l.contentLoaderInfo.addEventListener( flash.events.IOErrorEvent.IO_ERROR, function(e) onError(e.text, imgUrl) );
		l.contentLoaderInfo.addEventListener( flash.events.Event.COMPLETE, function(_) {
			var bmp : flash.display.Bitmap = cast( l.contentLoaderInfo.content );
			bd = bmp.bitmapData;
			onOneDone();
		});
		var ctx = new flash.system.LoaderContext(true);
		var r = new flash.net.URLRequest(imgUrl);
		l.load(r, ctx);
	}
	#end
}
