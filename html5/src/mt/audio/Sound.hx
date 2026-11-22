package mt.audio;

/**
 * flash.media.Sound, as far as Sfx uses it: decoded samples that play on the Audio backend.
 * Sfx reads its bank synchronously (getAsset), so the JS build preloads every sound first (preload, preloaded).
 * @spec html5.sound::sfx-like-flash
 */
class Sound {
	static var PRELOADED = new Map<String, Sound>();

	/** In milliseconds, like Flash. */
	public var length(default, null):Float = 0;
	public var samples(default, null):Dynamic;

	public function new() {}

	/** @spec html5.sound::sounds-preloaded: a sound not preloaded fails and names it. */
	public static function preloaded(name:String):Sound {
		if (!PRELOADED.exists(name))
			throw 'Sound "$name" is not preloaded: call Sound.preload before the game asks for it';
		return PRELOADED.get(name);
	}

	/** Like Flash: loops 0 and 1 both play once, N plays N times. startTime is in milliseconds. A sound not loaded yet gives no channel. */
	public function play(startTime = 0.0, loops = 0, ?sndTransform:SoundTransform):SoundChannel {
		if (samples == null)
			return null;
		var transform = sndTransform == null ? new SoundTransform() : sndTransform;
		var channel = new SoundChannel(transform);
		@:privateAccess channel.playing = Audio.backend.play(this, startTime, loops < 1 ? 1 : loops, transform.volume, transform.pan, channel.complete);
		return channel;
	}

	#if js
	public static function preload(name:String, url:String):js.lib.Promise<Sound> {
		var sound = new Sound();
		return sound.fetchAndDecode(url).then(function(_) {
			PRELOADED.set(name, sound);
			return sound;
		});
	}

	/** @spec html5.sound::download-like-flash */
	public function load(url:String, onComplete:Void->Void, onError:String->Void) {
		fetchAndDecode(url).then(function(_) onComplete(), function(error) onError('$url could not be loaded: $error'));
	}

	function fetchAndDecode(url:String):js.lib.Promise<Sound> {
		return js.Browser.self.fetch(url).then(function(response) {
			if (!response.ok)
				throw 'HTTP ${response.status}';
			return response.arrayBuffer();
		}).then(function(data) {
			return Audio.backend.decode(data);
		}).then(function(decoded) {
			samples = decoded.samples;
			length = decoded.lengthMs;
			return this;
		});
	}
	#end
}
