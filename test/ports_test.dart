// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library isolate.test.ports_test;

import 'dart:async';
import 'dart:isolate';

import 'package:isolate/ports.dart';
import 'package:test/test.dart';

const Duration _ms = Duration(milliseconds: 1);

void main() {
  group('SingleCallbackPort', testSingleCallbackPort);
  group('SingleCompletePort', testSingleCompletePort);
  group('SingleResponseFuture', testSingleResponseFuture);
  group('SingleResponseFuture', testSingleResultFuture);
  group('SingleResponseChannel', testSingleResponseChannel);
}

void testSingleCallbackPort() {
  test('Value', () {
    var completer = Completer.sync();
    var p = singleCallbackPort(completer.complete);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test('FirstValue', () {
    var completer = Completer.sync();
    var p = singleCallbackPort(completer.complete);
    p.send(42);
    p.send(37);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });
  test('Value', () {
    var completer = Completer.sync();
    var p = singleCallbackPort(completer.complete);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test('ValueBeforeTimeout', () {
    var completer = Completer.sync();
    var p = singleCallbackPort(completer.complete, timeout: _ms * 500);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test('Timeout', () {
    var completer = Completer.sync();
    singleCallbackPort(completer.complete,
        timeout: _ms * 100, timeoutValue: 37);
    return completer.future.then((v) {
      expect(v, 37);
    });
  });

  test('TimeoutFirst', () {
    var completer = Completer.sync();
    var p = singleCallbackPort(completer.complete,
        timeout: _ms * 100, timeoutValue: 37);
    Timer(_ms * 500, () => p.send(42));
    return completer.future.then((v) {
      expect(v, 37);
    });
  });
}

void testSingleCompletePort() {
  test('Value', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test('ValueCallback', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      return 87;
    });
    p.send(42);
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test('ValueCallbackFuture', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      return Future.delayed(_ms * 500, () => 88);
    });
    p.send(42);
    return completer.future.then((v) {
      expect(v, 88);
    });
  });

  test('ValueCallbackThrows', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      throw 89;
    });
    p.send(42);
    return completer.future.then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 89);
    });
  });

  test('ValueCallbackThrowsFuture', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      return Future.error(90);
    });
    p.send(42);
    return completer.future.then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 90);
    });
  });

  test('FirstValue', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer);
    p.send(42);
    p.send(37);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test('FirstValueCallback', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer, callback: (v) {
      expect(v, 42);
      return 87;
    });
    p.send(42);
    p.send(37);
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test('ValueBeforeTimeout', () {
    var completer = Completer.sync();
    var p = singleCompletePort(completer, timeout: _ms * 500);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test('Timeout', () {
    var completer = Completer.sync();
    singleCompletePort(completer, timeout: _ms * 100);
    return completer.future.then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is TimeoutException, isTrue);
    });
  });

  test('TimeoutCallback', () {
    var completer = Completer.sync();
    singleCompletePort(completer, timeout: _ms * 100, onTimeout: () => 87);
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test('TimeoutCallbackThrows', () {
    var completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100, onTimeout: () => throw 91);
    return completer.future.then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 91);
    });
  });

  test('TimeoutCallbackFuture', () {
    var completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100, onTimeout: () => Future.value(87));
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test('TimeoutCallbackThrowsFuture', () {
    var completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100, onTimeout: () => Future.error(92));
    return completer.future.then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 92);
    });
  });

  test('TimeoutCallbackSLow', () {
    var completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100,
        onTimeout: () => Future.delayed(_ms * 500, () => 87));
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test('TimeoutCallbackThrowsSlow', () {
    var completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100,
        onTimeout: () => Future.delayed(_ms * 500, () => throw 87));
    return completer.future.then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 87);
    });
  });

  test('TimeoutFirst', () {
    var completer = Completer.sync();
    var p =
        singleCompletePort(completer, timeout: _ms * 100, onTimeout: () => 37);
    Timer(_ms * 500, () => p.send(42));
    return completer.future.then((v) {
      expect(v, 37);
    });
  });
}

void testSingleResponseFuture() {
  test('FutureValue', () {
    return singleResponseFuture((SendPort p) {
      p.send(42);
    }).then((v) {
      expect(v, 42);
    });
  });

  test('FutureValueFirst', () {
    return singleResponseFuture((SendPort p) {
      p.send(42);
      p.send(37);
    }).then((v) {
      expect(v, 42);
    });
  });

  test('FutureError', () {
    return singleResponseFuture((SendPort p) {
      throw 93;
    }).then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 93);
    });
  });

  test('FutureTimeout', () {
    return singleResponseFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100)
        .then((v) {
      expect(v, null);
    });
  });

  test('FutureTimeoutValue', () {
    return singleResponseFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100, timeoutValue: 42)
        .then((v) {
      expect(v, 42);
    });
  });
}

void testSingleResultFuture() {
  test('Value', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.value(42), p);
    }).then((v) {
      expect(v, 42);
    });
  });

  test('ValueFirst', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.value(42), p);
      sendFutureResult(Future.value(37), p);
    }).then((v) {
      expect(v, 42);
    });
  });

  test('Error', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.error(94), p);
    }).then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test('ErrorFirst', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.error(95), p);
      sendFutureResult(Future.error(96), p);
    }).then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test('Error', () {
    return singleResultFuture((SendPort p) {
      throw 93;
    }).then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test('Timeout', () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100)
        .then((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is TimeoutException, isTrue);
    });
  });

  test('TimeoutValue', () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100, onTimeout: () => 42).then((v) {
      expect(v, 42);
    });
  });

  test('TimeoutError', () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100, onTimeout: () => throw 97).then((v) {
      expect(v, 42);
    }, onError: (e, s) {
      expect(e, 97);
    });
  });
}

void testSingleResponseChannel() {
  test('Value', () {
    var channel = SingleResponseChannel();
    channel.port.send(42);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test('ValueFirst', () {
    var channel = SingleResponseChannel();
    channel.port.send(42);
    channel.port.send(37);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test('ValueCallback', () {
    var channel = SingleResponseChannel(callback: (v) => 2 * v);
    channel.port.send(42);
    return channel.result.then((v) {
      expect(v, 84);
    });
  });

  test('ErrorCallback', () {
    var channel = SingleResponseChannel(callback: (v) => throw 42);
    channel.port.send(37);
    return channel.result.then((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });

  test('AsyncValueCallback', () {
    var channel = SingleResponseChannel(callback: (v) => Future.value(2 * v));
    channel.port.send(42);
    return channel.result.then((v) {
      expect(v, 84);
    });
  });

  test('AsyncErrorCallback', () {
    var channel = SingleResponseChannel(callback: (v) => Future.error(42));
    channel.port.send(37);
    return channel.result.then((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });

  test('Timeout', () {
    var channel = SingleResponseChannel(timeout: _ms * 100);
    return channel.result.then((v) {
      expect(v, null);
    });
  });

  test('TimeoutThrow', () {
    var channel =
        SingleResponseChannel(timeout: _ms * 100, throwOnTimeout: true);
    return channel.result.then((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v is TimeoutException, isTrue);
    });
  });

  test('TimeoutThrowOnTimeoutAndValue', () {
    var channel = SingleResponseChannel(
        timeout: _ms * 100,
        throwOnTimeout: true,
        onTimeout: () => 42,
        timeoutValue: 42);
    return channel.result.then((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v is TimeoutException, isTrue);
    });
  });

  test('TimeoutOnTimeout', () {
    var channel =
        SingleResponseChannel(timeout: _ms * 100, onTimeout: () => 42);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutAndValue', () {
    var channel = SingleResponseChannel(
        timeout: _ms * 100, onTimeout: () => 42, timeoutValue: 37);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test('TimeoutValue', () {
    var channel = SingleResponseChannel(timeout: _ms * 100, timeoutValue: 42);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutError', () {
    var channel =
        SingleResponseChannel(timeout: _ms * 100, onTimeout: () => throw 42);
    return channel.result.then((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutAsync', () {
    var channel = SingleResponseChannel(
        timeout: _ms * 100, onTimeout: () => Future.value(42));
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutAsyncError', () {
    var channel = SingleResponseChannel(
        timeout: _ms * 100, onTimeout: () => Future.error(42));
    return channel.result.then((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });
}
