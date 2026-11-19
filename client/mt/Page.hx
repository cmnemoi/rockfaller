package mt;

#if flash
class Page extends flash.display.Sprite {
    public function new() {
        super();
    }

    public function update():Void {}
}
#elseif openfl
class Page extends openfl.display.Sprite {
    public function new() {
        super();
    }

    public function update():Void {}
}
#else
class Page {
    public function new() {}

    public function update():Void {}
}
#end
