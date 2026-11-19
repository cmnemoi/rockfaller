package mt.flash;

class VarSecure {
    public var bug:Bool = false;

    var value:Int;

    public function new(initialValue:Int) {
        value = initialValue;
    }

    public function get():Int {
        return value;
    }

    public function setValue(v:Int):Void {
        value = v;
    }

    public function addValue(v:Int):Void {
        value += v;
    }
}
