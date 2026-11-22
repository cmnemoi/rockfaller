package tools;

import mt.audio.Audio;
import mt.audio.AudioBackend;
import mt.audio.Sound;
import mt.flash.Sfx;

/**
 * Checks the game's Sfx on the JS build's sound classes, with a fake audio backend.
 * Run: mise run html5:check:sound (compiled to JS, run by Node)
 */
class SoundCheck {
	static var backend:FakeBackend;

	static function main() {
		theRealVolumeMultipliesTheSoundTheGlobalAndTheChannelVolumes();
		mutingAChannelSilencesItsPlayingSoundsUntilUnmuted();
		replayingASoundStopsItFirst();
		aSoundThatEndsStopsPlayingAndCallsItsEndCallbackOnce();
		aStoppedSoundCallsNoEndCallback();
		aDisabledSfxPlaysNothing();
		aLoopOfNTurnsPlaysNTimesAndPlayPlaysOnce();
		aSoundNotPreloadedFailsWithItsName();
		aDownloadThatFailsNamesItsAddress(function() {
			aLongLoopStartedBeforeTheFirstClickKeepsPlaying(function() {
				aSoundStartedBeforeTheFirstClickIsHeardOnceTheContextRuns(function() {
					aShortSoundOverBeforeTheFirstClickIsNotStartedLater(function() trace("PASS"));
				});
			});
		});
	}

	/** A fresh fake backend and Sfx's global settings back to their defaults. */
	static function freshSfx():Sfx {
		backend = new FakeBackend();
		Audio.backend = backend;
		Sfx.enable();
		Sfx.unmuteGlobal();
		Sfx.setGlobalVolume(1);
		for (channel in 0...4) {
			Sfx.setChannelVolume(channel, 1);
			Sfx.unmuteChannel(channel);
		}
		var sound = new Sound();
		@:privateAccess sound.samples = "samples";
		@:privateAccess sound.length = 1000;
		return new Sfx(sound);
	}

	/** @spec html5.sound::sfx-like-flash */
	static function theRealVolumeMultipliesTheSoundTheGlobalAndTheChannelVolumes() {
		var sfx = freshSfx();
		Sfx.setGlobalVolume(0.8);
		Sfx.setChannelVolume(2, 0.5);

		sfx.playOnChannel(2, 0.5);

		check(near(backend.last().volume, 0.2), "0.5 x 0.8 x 0.5 plays at 0.2 (got " + backend.last().volume + ")");
	}

	/** @spec html5.sound::sfx-like-flash */
	static function mutingAChannelSilencesItsPlayingSoundsUntilUnmuted() {
		var sfx = freshSfx();
		sfx.playOnChannel(1, 0.5);

		Sfx.muteChannel(1);
		var muted = backend.last().volume;
		Sfx.unmuteChannel(1);

		check(muted == 0 && backend.last().volume == 0.5, "muting channel 1 silences its sound, unmuting brings 0.5 back (got " + muted + ", " + backend.last().volume + ")");
	}

	/** @spec html5.sound::sfx-like-flash */
	static function replayingASoundStopsItFirst() {
		var sfx = freshSfx();
		sfx.play();
		var first = backend.last();

		sfx.play();

		check(first.stopped && backend.started.length == 2 && !backend.last().stopped, "playing again stops the first playing, then starts a second one");
	}

	/** @spec html5.sound::sfx-like-flash */
	static function aSoundThatEndsStopsPlayingAndCallsItsEndCallbackOnce() {
		var sfx = freshSfx();
		var ends = 0;
		sfx.onEndOnce(function() ends++);
		sfx.play();

		backend.last().end();
		var playingAfterEnd = sfx.isPlaying();
		sfx.play();
		backend.last().end();

		check(!playingAfterEnd && ends == 1, "an ended sound stops playing, and its end callback runs once (got playing " + playingAfterEnd + ", " + ends + " calls)");
	}

	/** @spec html5.sound::sfx-like-flash */
	static function aStoppedSoundCallsNoEndCallback() {
		var sfx = freshSfx();
		var ends = 0;
		sfx.onEndOnce(function() ends++);
		sfx.play();

		sfx.stop();

		check(!sfx.isPlaying() && ends == 0 && backend.last().stopped, "a stopped sound stops playing without its end callback");
	}

	/** @spec html5.sound::sfx-like-flash */
	static function aDisabledSfxPlaysNothing() {
		var sfx = freshSfx();
		Sfx.disable();

		sfx.play();

		check(backend.started.length == 0 && !sfx.isPlaying(), "with Sfx disabled, nothing plays");
		Sfx.enable();
	}

	/** @spec html5.sound::sfx-like-flash */
	static function aLoopOfNTurnsPlaysNTimesAndPlayPlaysOnce() {
		var sfx = freshSfx();

		sfx.playLoop(3);
		var looped = backend.last().plays;
		sfx.play();

		check(looped == 3 && backend.last().plays == 1, "playLoop(3) plays 3 times, play() once (got " + looped + ", " + backend.last().plays + ")");
	}

	/** @spec html5.sound::sounds-preloaded */
	static function aSoundNotPreloadedFailsWithItsName() {
		var message:String = null;
		try Sfx.getAsset("Rockfaller_platypus.mp3") catch (error:Dynamic) message = Std.string(error);

		check(message != null && message.indexOf("Rockfaller_platypus.mp3") >= 0, "a sound not preloaded fails with its name (got " + message + ")");
	}

	/** @spec html5.sound::download-like-flash */
	static function aDownloadThatFailsNamesItsAddress(then:Void->Void) {
		freshSfx();
		var url = "http://127.0.0.1:9/Rockfaller_interface.mp3"; // nothing listens on port 9

		Sfx.download(null, url, function(_) check(false, "a failed download does not complete"), function(message) {
			check(message.indexOf(url) >= 0, "a failed download names its address (got " + message + ")");
			then();
		});
	}

	/** A Web Audio backend on a fake context, suspended like a browser's before the first gesture. */
	static function webAudioOnSuspendedContext():{backend:mt.audio.WebAudioBackend, context:FakeAudioContext, sfx:Sfx} {
		var context = new FakeAudioContext();
		var backend = new mt.audio.WebAudioBackend(cast context);
		Audio.backend = backend;
		Sfx.enable();
		Sfx.unmuteGlobal();
		var sound = new Sound();
		@:privateAccess sound.samples = "music";
		@:privateAccess sound.length = 120000; // a two-minute music
		return {backend: backend, context: context, sfx: new Sfx(sound)};
	}

	/** @spec html5::sound-starts-on-first-click: 999999 turns of a long music pass setTimeout's limit, which then fires at once */
	static function aLongLoopStartedBeforeTheFirstClickKeepsPlaying(then:Void->Void) {
		var setup = webAudioOnSuspendedContext();

		setup.sfx.playLoop(999999, 0.5);

		haxe.Timer.delay(function() {
			check(setup.sfx.isPlaying(), "a music looped 999999 times, started before the first click, still plays a moment later");
			setup.sfx.stop();
			then();
		}, 50);
	}

	/** @spec html5::sound-starts-on-first-click: the menu music starts before the player's first click */
	static function aSoundStartedBeforeTheFirstClickIsHeardOnceTheContextRuns(then:Void->Void) {
		var setup = webAudioOnSuspendedContext();
		setup.sfx.playLoop(999999, 0.5);

		haxe.Timer.delay(function() {
			setup.context.run();

			check(setup.context.started.length == 1, "once the context runs, the music starts for real (got " + setup.context.started.length + " sources)");
			check(setup.context.started[0].offsetSeconds > 0.05, "where it is by now (got " + setup.context.started[0].offsetSeconds + " s)");
			check(near(setup.context.started[0].gain, 0.5), "at its volume (got " + setup.context.started[0].gain + ")");
			setup.sfx.stop();
			then();
		}, 80);
	}

	/** @spec html5::sound-starts-on-first-click */
	static function aShortSoundOverBeforeTheFirstClickIsNotStartedLater(then:Void->Void) {
		var setup = webAudioOnSuspendedContext();
		@:privateAccess setup.sfx.sound.length = 20;
		setup.sfx.play();

		haxe.Timer.delay(function() {
			setup.context.run();

			check(!setup.sfx.isPlaying() && setup.context.started.length == 0, "a 20 ms sound over before the first click is not started later");
			then();
		}, 80);
	}

	static function near(value:Float, expected:Float) {
		return Math.abs(value - expected) < 1e-9;
	}

	static function check(condition:Bool, expectation:String) {
		if (!condition)
			throw "FAILED: " + expectation;
	}
}

private class FakePlaying implements PlayingSound {
	public var plays:Int;
	public var volume:Float;
	public var stopped = false;
	var onEnded:Void->Void;

	public function new(plays, volume, onEnded) {
		this.plays = plays;
		this.volume = volume;
		this.onEnded = onEnded;
	}

	public function stop() stopped = true;
	public function setTransform(volume:Float, pan:Float) this.volume = volume;
	public function positionMs() return 0.0;

	/** The sound reaches its end on its own. */
	public function end() onEnded();
}

private class FakeBackend implements AudioBackend {
	public var started:Array<FakePlaying> = [];

	public function new() {}

	public function last() return started[started.length - 1];

	public function play(sound:Sound, startMs:Float, plays:Int, volume:Float, pan:Float, onEnded:Void->Void):PlayingSound {
		var playing = new FakePlaying(plays, volume, onEnded);
		started.push(playing);
		return playing;
	}

	public function decode(data:js.lib.ArrayBuffer):js.lib.Promise<{samples:Dynamic, lengthMs:Float}> {
		return js.lib.Promise.reject("the fake backend decodes nothing");
	}
}

/** The parts of AudioContext the backend uses. run() is the first gesture: the context starts and says so. */
private class FakeAudioContext {
	public var state = "suspended";
	public var currentTime = 0.0;
	public var destination = {};
	public var started:Array<{offsetSeconds:Float, gain:Float}> = [];
	var stateListeners:Array<Dynamic->Void> = [];

	public function new() {}

	public function resume() {
		return js.lib.Promise.resolve(null);
	}

	public function run() {
		state = "running";
		for (listener in stateListeners)
			listener(null);
	}

	public function addEventListener(type:String, listener:Dynamic->Void) {
		if (type == "statechange")
			stateListeners.push(listener);
	}

	public function createGain():Dynamic {
		return {gain: {value: 1.0}, connect: function(_) {}};
	}

	public function createStereoPanner():Dynamic {
		return {pan: {value: 0.0}, connect: function(_) {}};
	}

	public function createBufferSource():Dynamic {
		var context = this;
		var source:Dynamic = {buffer: null, loop: false, connect: function(gain) {}, stop: function() {}};
		var gainNode:Dynamic = null;
		source.connect = function(node) gainNode = node;
		source.start = function(when, offsetSeconds, ?duration) context.started.push({offsetSeconds: offsetSeconds, gain: gainNode.gain.value});
		return source;
	}
}
