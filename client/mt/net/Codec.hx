package mt.net;

import Protocol;

class Codec {
    public static function getInitData():Dynamic {
        return {level: -1, urlImages: "", urlSounds: ""};
    }

    public static function requestUrl(
        url:String,
        data:Dynamic,
        onSuccess:Dynamic->Void,
        onError:Dynamic->Void,
        ?retry:Int
    ):Void {
        var response = Protocol.offlineResponse(data);
        // Answer on the next frame, like a real server: callers set their
        // "waiting for the server" state after they send the request.
        haxe.Timer.delay(function() {
            if (response != null && onSuccess != null)
                onSuccess(response);
            else if (onError != null)
                onError("Offline response unavailable for " + url);
        }, 0);
    }
}
