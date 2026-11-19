package mt;

class MLib {
    public static inline var PI:Float = 3.141592653589793;
    public static inline var PI2:Float = 6.283185307179586;
    public static inline function toRad(degrees:Float):Float {
        return degrees * Math.PI / 180.0;
    }

    public static inline function round(v:Float):Int {
        return Std.int(Math.round(v));
    }

    public static inline function floor(v:Float):Int {
        return Std.int(Math.floor(v));
    }

    public static inline function ceil(v:Float):Int {
        return Std.int(Math.ceil(v));
    }

    public static inline function max(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

    public static inline function fmax(a:Float, b:Float):Float {
        return a > b ? a : b;
    }

    public static inline function fmin(a:Float, b:Float):Float {
        return a < b ? a : b;
    }

    public static inline function fabs(v:Float):Float {
        return v < 0 ? -v : v;
    }

    public static inline function clamp(v:Int, min:Int, max:Int):Int {
        return v < min ? min : (v > max ? max : v);
    }

    public static inline function fclamp(v:Float, min:Float, max:Float):Float {
        return v < min ? min : (v > max ? max : v);
    }

    public static inline function wrap(v:Int, min:Int, max:Int):Int {
        if (max < min) {
            return v;
        }
        var size = max - min + 1;
        var n = (v - min) % size;
        if (n < 0) {
            n += size;
        }
        return min + n;
    }

    public static inline function sMod(v:Float, m:Float):Float {
        if (m == 0) {
            return 0;
        }
        var r = v % m;
        if (r < 0) {
            r += m;
        }
        return r;
    }

    public static inline function hMod(v:Float, half:Float):Float {
        if (half == 0) {
            return 0;
        }
        var size = half * 2.0;
        var r = sMod(v + half, size) - half;
        return r;
    }

    public static inline function wrapToPi(v:Float):Float {
        return hMod(v, Math.PI);
    }
}
