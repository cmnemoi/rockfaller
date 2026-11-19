package mt.device;

class FriendRequest {
    public static function friends(
        arg1:Null<Dynamic>,
        arg2:Null<Dynamic>,
        callback:Null<Array<mt.net.FriendRequest.Friend>>->Void
    ):Void {
        callback([]);
    }

    public static function request(
        typeIndex:Int,
        message:String,
        friends:Array<mt.net.FriendRequest.Friend>,
        data:Null<String>,
        callback:Void->Void
    ):Void {
        callback();
    }

    public static function list(callback:mt.net.FriendRequest.ListResp->Void):Void {
        callback([]);
    }

    public static function accept(
        ids:Array<Int>,
        reqDataFn:Int->{ message:String, data:Null<String> },
        callback:Dynamic->Void
    ):Void {
        callback([]);
    }
}
