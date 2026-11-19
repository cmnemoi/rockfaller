package mt;

class Worker {
    public function new() {}

    public function checkDone():Void {}

    /**
     * Runs the task on a later frame, like Motion-Twin's background worker.
     * Callers rely on it: AssetManager.WorldBitmap locks right after enqueue and
     * unlocks on completion, so a task run at once would leave the lock closed.
     */
    public function enqueue(task:WorkerTask):WorkerTask {
        if (task != null) {
            haxe.Timer.delay(task.execute, 0);
        }
        return task;
    }
}

class WorkerTask {
    var work:Void->Void;
    var done:Bool = false;
    var _onComplete:Null<Void->Void>;

    public var onComplete(get, set):Null<Void->Void>;

    public function new(work:Void->Void) {
        this.work = work;
    }

    public function execute():Void {
        if (done) {
            return;
        }

        if (work != null) {
            work();
        }

        done = true;
        if (_onComplete != null) {
            _onComplete();
        }
    }

    function get_onComplete():Null<Void->Void> {
        return _onComplete;
    }

    function set_onComplete(cb:Null<Void->Void>):Null<Void->Void> {
        _onComplete = cb;
        if (done && _onComplete != null) {
            _onComplete();
        }
        return _onComplete;
    }
}
