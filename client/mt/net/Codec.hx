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
        if (response != null && onSuccess != null)
            onSuccess(response);
        else if (onError != null)
            onError("Offline response unavailable for " + url);
    }
}
