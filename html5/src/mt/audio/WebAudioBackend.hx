package mt.audio;

import mt.audio.AudioBackend.PlayingSound;

/**
 * Plays sounds with Web Audio: a buffer source through a gain (volume) and a stereo panner (pan).
 * @spec html5::sound-starts-on-first-click: browsers keep the audio context suspended until a gesture,
 * so it resumes on the first pointer press or key press. Until then a sound plays in silence: it lasts
 * its length, then ends, so the game's logic (isPlaying, end callbacks) runs the same.
 */
class WebAudioBackend implements AudioBackend {
	public var context(default, null):js.html.audio.AudioContext;

	public function new() {
		context = new js.html.audio.AudioContext();
		var resume = function(_) if (context.state == SUSPENDED) context.resume();
		js.Browser.window.addEventListener("pointerdown", resume, true);
		js.Browser.window.addEventListener("keydown", resume, true);
	}

	public function decode(data:js.lib.ArrayBuffer):js.lib.Promise<{samples:Dynamic, lengthMs:Float}> {
		return context.decodeAudioData(data).then(function(buffer) return {samples: (buffer : Dynamic), lengthMs: buffer.duration * 1000});
	}

	public function play(sound:Sound, startMs:Float, plays:Int, volume:Float, pan:Float, onEnded:Void->Void):PlayingSound {
		if (context.state != RUNNING)
			return new SilentSound(sound.length * plays - startMs, onEnded);
		return new WebAudioSound(context, sound.samples, startMs, plays, volume, pan, onEnded);
	}
}

private class WebAudioSound implements PlayingSound {
	var context:js.html.audio.AudioContext;
	var source:js.html.audio.AudioBufferSourceNode;
	var gain:js.html.audio.GainNode;
	var panner:js.html.audio.StereoPannerNode;
	var startedAt:Float;
	var startMs:Float;
	var lengthMs:Float;
	var stopped = false;

	public function new(context, buffer:js.html.audio.AudioBuffer, startMs:Float, plays:Int, volume:Float, pan:Float, onEnded:Void->Void) {
		this.context = context;
		this.startMs = startMs;
		lengthMs = buffer.duration * 1000;
		gain = context.createGain();
		panner = context.createStereoPanner();
		setTransform(volume, pan);
		source = context.createBufferSource();
		source.buffer = buffer;
		source.connect(gain);
		gain.connect(panner);
		panner.connect(context.destination);
		source.onended = function() if (!stopped) onEnded();
		startedAt = context.currentTime;
		if (plays > 1) {
			// Loops back to the start of the buffer, like Flash, then stops after the last play.
			source.loop = true;
			source.start(0, startMs / 1000, (lengthMs * plays - startMs) / 1000);
		} else
			source.start(0, startMs / 1000);
	}

	public function stop() {
		stopped = true;
		source.stop();
	}

	public function setTransform(volume:Float, pan:Float) {
		gain.gain.value = volume;
		panner.pan.value = pan;
	}

	public function positionMs():Float {
		return (startMs + (context.currentTime - startedAt) * 1000) % lengthMs;
	}
}

/** A sound played before the audio context runs: heard by nobody, but it lasts and ends like a real one. */
private class SilentSound implements PlayingSound {
	var timer:haxe.Timer;
	var startedAt = haxe.Timer.stamp();

	public function new(durationMs:Float, onEnded:Void->Void) {
		timer = haxe.Timer.delay(onEnded, Std.int(Math.max(0, durationMs)));
	}

	public function stop() timer.stop();
	public function setTransform(volume:Float, pan:Float) {}
	public function positionMs() return (haxe.Timer.stamp() - startedAt) * 1000;
}
