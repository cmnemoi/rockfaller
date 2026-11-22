package ;

#if flash
import flash.events.KeyboardEvent;
import flash.Lib;
import flash.ui.Keyboard;
#end

import Common;

import process.Game;
import process.Levels;
import data.Settings;

#if !flash
// The JS build reads the keyboard from the window: for these keys, DOM key codes are Flash's.
private typedef KeyboardEvent = js.html.KeyboardEvent;

private class Keyboard {
	public static inline var LEFT = 37;
	public static inline var RIGHT = 39;
	public static inline var A = 65;
	public static inline var D = 68;
	public static inline var L = 76;
	public static inline var M = 77;
	public static inline var P = 80;
	public static inline var R = 82;
	public static inline var T = 84;
}
#end

/**
 * ...
 * @author Tipyx
 */
class Input
{
	public var left:Bool = false;
	public var right:Bool = false;
	public var a:Bool = false;
	public var p:Bool = false;
	
	var game	: process.Game;
	var levels	: process.Levels;

	public function new() 
	{
		this.game = Game.ME;
		
		#if flash
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		#else
		js.Browser.window.addEventListener("keydown", onKeyDown);
		js.Browser.window.addEventListener("keyup", onKeyUp);
		#end
	}
	
	private function onKeyDown(e:KeyboardEvent):Void {
		this.game = Game.ME;
		this.levels = Levels.ME;
		
		if (game != null || levels != null) {
			if (e.keyCode == Keyboard.LEFT)		left = true;
			if (e.keyCode == Keyboard.RIGHT)	right = true;
			if (e.keyCode == Keyboard.A)		a = true;
			#if debug
			if (e.keyCode == Keyboard.P)		p = true;
			#end			
		}
	}
	
	private function onKeyUp(e:KeyboardEvent):Void {
		this.game = Game.ME;
		this.levels = Levels.ME;
		
		if (game != null || levels != null) {
			if (e.keyCode == Keyboard.LEFT)		left = false;
			if (e.keyCode == Keyboard.RIGHT)	right = false;
			if (e.keyCode == Keyboard.A)		a = false;
			#if debug
			if (e.keyCode == Keyboard.P)		p = false;
			if (e.keyCode == Keyboard.L) {
				//manager.SpecialManager.GEYSER_MOVE(4, true);
				//manager.SpecialManager.GEYSER();
			}
			if (e.keyCode == Keyboard.M) {
				//manager.SpecialManager.GEYSER_MOVE(7, false);
				//manager.SpecialManager.AR_GEYSER[0].reset();
			}
			if (e.keyCode == Keyboard.D)
				Main.ME.showDrawProfiler();
			if (e.keyCode == Keyboard.R)
				Main.ME.resetDrawProfiler();
			#if mBase
			if (e.keyCode == Keyboard.T)
				MobileServer.SEND_PROTOCOL( null );
			#end
			#end
		}
	}
	
	public function destroy() {
		#if flash
		Lib.current.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		Lib.current.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		#else
		js.Browser.window.removeEventListener("keydown", onKeyDown);
		js.Browser.window.removeEventListener("keyup", onKeyUp);
		#end
	}
}
