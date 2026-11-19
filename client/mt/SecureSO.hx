package mt;

typedef SecureSOConfig = {
    var name:String;
    var aesKey:Dynamic;
    var aesIv:Dynamic;
    var v2:Bool;
};

class SecureSO {
    static var stores:Map<String, Map<String, Dynamic>> = new Map();

    var store:Map<String, Dynamic>;

    public function new(config:SecureSOConfig) {
        if (!stores.exists(config.name)) {
            stores.set(config.name, new Map());
        }
        store = stores.get(config.name);
    }

    public function get(key:String):Dynamic {
        return store.get(key);
    }

    public function set(key:String, value:Dynamic):Void {
        store.set(key, value);
    }
}
