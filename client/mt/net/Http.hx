package mt.net;

class Http {
    public static var DEFAULT_TIMEOUT:Int = 30;

    var url:String;
    var params:Map<String, String>;

    public function new(url:String) {
        this.url = url;
        params = new Map();
    }

    public function setParameter(name:String, value:String):Void {
        params.set(name, value);
    }

    public function request(post:Bool):Void {
        trace("[mt.net.Http] request suppressed (offline): " + url + " post=" + post + " params=" + params);
    }
}
