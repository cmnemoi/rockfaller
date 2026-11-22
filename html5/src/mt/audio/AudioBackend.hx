package mt.audio;

/** What plays sounds: Web Audio in the browser (WebAudioBackend), a fake one in tests. */
interface AudioBackend {
	/** Plays the sound `plays` times from startMs, and calls onEnded when it finishes on its own (not on stop). */
	function play(sound:Sound, startMs:Float, plays:Int, volume:Float, pan:Float, onEnded:Void->Void):PlayingSound;
	#if js
	function decode(data:js.lib.ArrayBuffer):js.lib.Promise<{samples:Dynamic, lengthMs:Float}>;
	#end
}

interface PlayingSound {
	function stop():Void;
	function setTransform(volume:Float, pan:Float):Void;
	function positionMs():Float;
}
