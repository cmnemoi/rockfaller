package mt;

class Console {
    static var lines:Array<String> = [];

    public static function log(v:Dynamic):Void {
        var line = Std.string(v);
        lines.push(line);
        trace(line);
    }

    public static function dbg(v:Dynamic):Void {
        log(v);
    }

    public static function dump():String {
        return lines.join("\n");
    }
}
