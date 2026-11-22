package mt.audio;

/** flash.media.SoundChannel, as far as Sfx uses it: one playing of a sound. */
class SoundChannel {
	public static inline var SOUND_COMPLETE = "soundComplete";

	public var position(get, never):Float;
	public var soundTransform(get, set):SoundTransform;

	var playing:AudioBackend.PlayingSound;
	var transform:SoundTransform;
	var completeListeners:Array<Dynamic->Void> = [];

	@:allow(mt.audio.Sound)
	function new(transform:SoundTransform) {
		this.transform = transform;
	}

	/** Like Flash, only SOUND_COMPLETE: the end of the sound on its own, never a stop(). */
	public function addEventListener(type:String, listener:Dynamic->Void) {
		if (type == SOUND_COMPLETE)
			completeListeners.push(listener);
	}

	public function stop() {
		playing.stop();
	}

	@:allow(mt.audio.Sound)
	function complete() {
		for (listener in completeListeners.copy())
			listener(null);
	}

	function get_position() return playing.positionMs();
	function get_soundTransform() return transform;

	function set_soundTransform(t:SoundTransform) {
		transform = t;
		playing.setTransform(t.volume, t.pan);
		return t;
	}
}
