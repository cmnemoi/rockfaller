package mt.device;

class Cash {
    public static function listProducts(category:String, callback:Null<ProductsData>->Void):Void {
        callback(null);
    }
}

typedef Product = {
    var _moneyA:{ _quantity:Int };
    var _localEstimatedPrice:Null<String>;
    var _price:String;
    var _buy:(Transaction->Void)->Void;
};

typedef ProductsData = {
    var list:Array<Product>;
    var otherPayment:Null<(Transaction->Void)->Void>;
};

typedef Transaction = {};
