package promise {

public class Enumerator {

  private var _promise:Promise;

  private var _promises:Array;

  private var _remaining:int = 0;
  private var _abortOnReject:Boolean = true;
  private var _result:Array;

  public function get promise():Promise {
    return _promise;
  }

  public function Enumerator(promises:Array, abortOnReject:Boolean) {
    this._promise = new Promise(function ():void {
    });
    this._abortOnReject = abortOnReject;
    this._promises = promises;
    if (this._promises) {
      this._remaining = _promises.length;
      this._result = new Array(_promises.length);
      this.enumerate();
    }

    if (this._remaining === 0) {
      this._promise.fullfill(this._result);
    }
  }

  private function enumerate():void {
    for (var i:int = 0; this._promise.state === Promise.PENDING && i < this._promises.length; i++) {
      var entry:Promise = this._promises[i];
      if (entry.state !== Promise.PENDING) {
        this.settledAt(entry.state, i, entry.result);
      } else {
        this.willSettleAt(entry, i);
      }
    }
  }

  private function settledAt(state:int, i:int, value:*):void {
    var promise:Promise = this._promise;

    if (promise.state === Promise.PENDING) {
      this._remaining--;

      if (this._abortOnReject && state === Promise.REJECTED) {
        promise.reject(value);
      } else {
        if (this._abortOnReject) {
          this._result[i] = value;
        } else {
          this._result[i] = state === Promise.REJECTED ? {status:  "rejected", reason: value} : {status: "fulfilled", value: value};
        }
      }
    }
    if (this._remaining === 0) {
      promise.fullfill(this._result);
    }
  }

  private function willSettleAt(promise:Promise, i:int):void {
    var enumerator:Enumerator = this;

    promise.subscribe(null, function (value:*):void {
      enumerator.settledAt(Promise.FULFILLED, i, value);
    }, function (reason:*):void {
      enumerator.settledAt(Promise.REJECTED, i, reason);
    });
  }

}
}
