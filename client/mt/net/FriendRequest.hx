package mt.net;

class FriendRequest {}

typedef Friend = {
    var net:Int;
    var id:String;
    var name:String;
    var avatar:Null<String>;
    var invitable:Bool;
};

typedef ListResp = Array<{ i:Int, f:Friend, t:Int, d:Null<Dynamic> }>;
