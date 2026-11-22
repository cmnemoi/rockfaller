package mt.audio;

/** flash.media.SoundTransform, as far as Sfx uses it. */
class SoundTransform {
	public var volume:Float;
	public var pan:Float;

	public function new(volume = 1.0, pan = 0.0) {
		this.volume = volume;
		this.pan = pan;
	}
}
