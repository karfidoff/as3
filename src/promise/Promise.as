package com.groveware.exforma.mobile.script {
import flash.utils.setTimeout;

public class Promise {

  public static const PENDING:int = 0;
  public static const FULFILLED:int = 1;
  public static const REJECTED:int = 2;

  private var _state:int = PENDING;
  private var _result:* = null;
  private var _callbacks:Array = [];

  public function get state():int {
    return _state;
  }

  public function get result():* {
    return _result;
  }

  public function Promise(resolver:Function) {
    if (!(resolver is Function)) {
      throw new Error("Promise resolver is not a function");
    }
    executeNext(function ():void {
      try {
        resolver(function (value:*):void {
          resolve(value);
        }, function (reason:*):void {
          reject(reason);
        });
      } catch (e:Error) {
        reject(e);
      }

    });
  }

  internal function resolve(value:*):void {
    if (this === value) {
      reject(new TypeError("You cannot resolve a promise with itself"));
    } else if (value is Promise) {
      handleOwnThenable(value);
    } else {
      fullfill(value);
    }
  }

  internal function reject(reason:*):void {
    if (this._state !== PENDING) {
      return;
    }
    this._result = reason;
    this._state = REJECTED;
    executeNext(process);
  }

  public function then(onFulfilled:Function = null, onRejected:Function = null):Promise {
    if (_state === FULFILLED && onFulfilled == null || _state === REJECTED && onRejected == null) {
      return this;
    }

    var child:Promise = new Promise(noop);
    var result:* = this._result;

    if (_state != PENDING) {
      var callback:Function = _state == FULFILLED ? onFulfilled : onRejected;
      executeNext(function ():void {
        invokeCallback(_state, child, callback, result);
      });
    } else {
      subscribe(child, onFulfilled, onRejected);
    }

    return child;
  }

  private function handleOwnThenable(thenable:Promise):void {
    if (thenable._state === FULFILLED) {
      fullfill(thenable._result);
    } else if (_state === REJECTED) {
      reject(thenable._result);
    } else {
      thenable.subscribe(undefined, function (value:*):void {
        resolve(value);
      }, function (reason:*):void {
        reject(reason);
      });
    }
  }

  internal function fullfill(value:*):void {
    if (this._state !== PENDING) {
      return;
    }

    this._result = value;
    this._state = FULFILLED;

    if (this._callbacks.length > 0) {
      executeNext(process);
    }
  }

  internal function subscribe(child:Promise, onResolved:Function, onRejected:Function):void {
    _callbacks.push({
      child: child,
      onResolved: onResolved,
      onRejected: onRejected
    });

    if (length === 0 && this._state != PENDING) {
      executeNext(process);
    }
  }

  private function process():void {
    if (_callbacks.length === 0 || _state == PENDING) {
      return;
    }

    for (var i:int = 0; i < _callbacks.length; i += 3) {
      var child:Promise = _callbacks[i].child;
      var callback:Function = _state == FULFILLED ? _callbacks[i].onResolved : _callbacks[i].onRejected;

      if (child) {
        invokeCallback(_state, child, callback, _result);
      } else {
        callback(_result);
      }
    }

    this._callbacks.length = 0;
  }

  private function invokeCallback(settled:int, promise:Promise, callback:Function, result:*):void {
    var hasCallback:Boolean = callback !== null,
            value:*, error:*, succeeded:Boolean, failed:Boolean;

    if (hasCallback) {
      try {
        value = callback(result);
        succeeded = true;
      } catch (e:Error) {
        failed = true;
        error = e;
        value = null;
      }

      if (promise === value) {
        promise.reject(new TypeError('A promises callback cannot return that same promise.'));
        return;
      }
    } else {
      value = result;
      succeeded = true;
    }

    if (promise._state !== PENDING) {
      // noop
    } else if (hasCallback && succeeded) {
      promise.resolve(value);
    } else if (failed) {
      promise.reject(error);
    } else if (settled === FULFILLED) {
      promise.fullfill(value);
    } else if (settled === REJECTED) {
      promise.reject(value);
    }
  }

  public function error(onRejection:Function):Promise {
    return this.then(null, onRejection);
  }

  public function always(alwaysFunction:Function):Promise {
    if (!alwaysFunction) {
      return this;
    }
    if (_state != PENDING) {
      executeNext(alwaysFunction);
      return this;
    }
    var child:Promise = new Promise(noop);
    subscribe(child, alwaysFunction, alwaysFunction);
    return child;
  }

  static public function noop(resolve:Function, reject:Function):void {
  }

  private function executeNext(callback:Function, parameters:Array = null):void {
    function execute():void {
      callback.apply(null, parameters);
    }

    setTimeout(execute, 0);
  }

  public static function all(entries:Array):Promise {
    return new Enumerator(entries, true).promise;
  }

  public static function allSettled(entries:Array):Promise {
    return new Enumerator(entries, false).promise;
  }

  public static function resolve(object:* = null):Promise {
    if (object is Promise) {
      return Promise(object);
    } else {
      var promise:Promise = new Promise(noop);
      promise.resolve(object);
      return promise;
    }
  }

  public static function reject(object:* = null):Promise {
    var promise:Promise = new Promise(noop);
    promise.reject(object);
    return promise;
  }


}

}

