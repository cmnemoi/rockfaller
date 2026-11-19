package mt.device;

class User {
    static var logged:Bool = false;

    public static function isLogged():Bool {
        return logged;
    }

    public static function login():Void {
        logged = true;
    }

    public static function logout():Void {
        logged = false;
    }

    public static function getName():String {
        return "Guest";
    }

    public static function syncGoals():Void {}

    public static function play(path:String):Void {
        trace("[User] play path=" + path);
    }
}
