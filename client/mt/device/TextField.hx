package mt.device;

class TextField {
    public var text(default, set):String = "";
    public var textSize:Float = 12;
    public var width:Int = 0;
    public var height:Int = 0;
    public var type:TextFieldType = TF_Text;
    public var x:Int = 0;
    public var y:Int = 0;
    public var textColor:Int = 0xFFFFFFFF;
    public var onTextChanged:Null<String->Void>;

    public function new() {}

    function set_text(v:String):String {
        text = v == null ? "" : v;
        if (onTextChanged != null) {
            onTextChanged(text);
        }
        return text;
    }

    public function destroy():Void {
        onTextChanged = null;
    }
}

enum TextFieldType {
    TF_Text;
    TF_Number;
}
