package mt.device;

class GameCenter {
    public static function name():Null<String> {
        return null;
    }

    public static function isLogged():Bool {
        return false;
    }

    public static function showAchievements():Void {}

    public static function connect(callback:Bool->Void):Void {
        callback(false);
    }

    public static function isAvailable():Bool {
        return false;
    }
}
