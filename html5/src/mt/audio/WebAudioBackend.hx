package mt.audio;

import mt.audio.AudioBackend.PlayingSound;

/**
 * Plays sounds with Web Audio: a buffer source through a gain (volume) and a stereo panner (pan).
 * @spec html5::sound-starts-on-first-click: browsers keep the audio context suspended until a gesture,
 * so it resumes on the first pointer press or key press. Until then a sound plays in silence: it lasts
 * its length, then ends, so the game's logic (isPlaying, end callbacks) runs the same. Once the context runs,
 * a sound still playing in silence (the music of the first screen) goes on aloud, where it is by then.
 */
class WebAudioBackend implements AudioBackend {
	public var context(default, null):js.html.audio.AudioContext;
	var silent:Array<SilentSound> = [];

	/** context: the browser's own by default; the checks give a fake one. */
	public function new(?context:js.html.audio.AudioContext) {
		this.context = context != null ? context : new js.html.audio.AudioContext();
		var resume = function(_) if (this.context.state == SUSPENDED) this.context.resume();
		this.context.addEventListener("statechange", function(_) if (this.context.state == RUNNING) hearSilentSounds());
		if (js.Syntax.typeof(js.Browser.window) != "undefined") {
			js.Browser.window.addEventListener("pointerdown", resume, true);
			js.Browser.window.addEventListener("keydown", resume, true);
		}
	}

	public function decode(data:js.lib.ArrayBuffer):js.lib.Promise<{samples:Dynamic, lengthMs:Float}> {
		return context.decodeAudioData(data).then(function(buffer) return {samples: (buffer : Dynamic), lengthMs: buffer.duration * 1000});
	}

	public function play(sound:Sound, startMs:Float, plays:Int, volume:Float, pan:Float, onEnded:Void->Void):PlayingSound {
		if (context.state != RUNNING) {
			var playing = new SilentSound(sound, startMs, plays, volume, pan, onEnded);
			silent.push(playing);
			return playing;
		}
		return new WebAudioSound(context, sound, startMs, plays, volume, pan, onEnded);
	}

	function hearSilentSounds() {
		for (playing in silent)
			playing.becomeAudible(context);
		silent = [];
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

	public function new(context, sound:Sound, startMs:Float, plays:Int, volume:Float, pan:Float, onEnded:Void->Void) {
		this.context = context;
		this.startMs = startMs;
		lengthMs = sound.length;
		gain = context.createGain();
		panner = context.createStereoPanner();
		setTransform(volume, pan);
		source = context.createBufferSource();
		source.buffer = sound.samples;
		source.connect(gain);
		gain.connect(panner);
		panner.connect(context.destination);
		source.onended = function() if (!stopped) onEnded();
		startedAt = context.currentTime;
		var offsetMs = startMs % lengthMs;
		if (plays > 1) {
			// Loops back to the start of the buffer, like Flash, then stops after the last play.
			source.loop = true;
			source.start(0, offsetMs / 1000, (lengthMs * plays - startMs) / 1000);
		} else
			source.start(0, offsetMs / 1000);
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

/**
 * A sound played before the audio context runs: heard by nobody, but it lasts and ends like a real one.
 * If it is still playing when the context runs, it goes on aloud from where it is.
 */
private class SilentSound implements PlayingSound {
	// setTimeout fires at once past 2^31 - 1 ms (24.8 days): a longer sound, like 999999 turns of a music, never ends here.
	static inline var MAX_DELAY_MS = 2147483647.0;

	var sound:Sound;
	var startMs:Float;
	var plays:Int;
	var volume:Float;
	var pan:Float;
	var onEnded:Void->Void;
	var startedAt = haxe.Timer.stamp();
	var timer:haxe.Timer;
	var over = false;
	var audible:PlayingSound;

	public function new(sound:Sound, startMs:Float, plays:Int, volume:Float, pan:Float, onEnded:Void->Void) {
		this.sound = sound;
		this.startMs = startMs;
		this.plays = plays;
		this.volume = volume;
		this.pan = pan;
		this.onEnded = onEnded;
		var durationMs = sound.length * plays - startMs;
		if (durationMs < MAX_DELAY_MS)
			timer = haxe.Timer.delay(end, Std.int(Math.max(0, durationMs)));
	}

	function end() {
		over = true;
		onEnded();
	}

	function elapsedMs():Float {
		return (haxe.Timer.stamp() - startedAt) * 1000;
	}

	public function becomeAudible(context:js.html.audio.AudioContext) {
		if (over) return;
		if (timer != null) timer.stop();
		audible = new WebAudioSound(context, sound, startMs + elapsedMs(), plays, volume, pan, onEnded);
	}

	public function stop() {
		over = true;
		if (timer != null) timer.stop();
		if (audible != null) audible.stop();
	}

	public function setTransform(volume:Float, pan:Float) {
		this.volume = volume;
		this.pan = pan;
		if (audible != null) audible.setTransform(volume, pan);
	}

	public function positionMs():Float {
		return audible != null ? audible.positionMs() : (startMs + elapsedMs()) % sound.length;
	}
}
