package mt.device;

class EventTracker {
    public static function view(screenName:String):Void {
        trace("[EventTracker] view=" + screenName);
    }

    public static function track(eventName:String, eventValue:String):Void {
        trace("[EventTracker] track=" + eventName + " value=" + eventValue);
    }

    public static function creditSpent(currency:String, amount:Int, item:String):Void {
        trace("[EventTracker] creditSpent currency=" + currency + " amount=" + amount + " item=" + item);
    }

    public static function levelAchieved(level:Int):Void {
        trace("[EventTracker] levelAchieved level=" + level);
    }

    public static function tutorialPresented(description:String):Void {
        trace("[EventTracker] tutorialPresented=" + description);
    }

    public static function tutorialCompleted(description:String):Void {
        trace("[EventTracker] tutorialCompleted=" + description);
    }

    public static function twTrack(eventName:String, data:Dynamic):Void {
        trace("[EventTracker] twTrack=" + eventName + " data=" + Std.string(data));
    }
}
