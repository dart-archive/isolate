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
    final completer = Completer.sync();
    final p = singleCallbackPort(completer.complete);
    p.send(42);
    return completer.future.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('FirstValue', () {
    final completer = Completer.sync();
    final p = singleCallbackPort(completer.complete);
    p.send(42);
    p.send(37);
    return completer.future.then<Null>((v) {
      expect(v, 42);
    });
  });
  test('Value', () {
    final completer = Completer.sync();
    final p = singleCallbackPort(completer.complete);
    p.send(42);
    return completer.future.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('ValueBeforeTimeout', () {
    final completer = Completer.sync();
    final p = singleCallbackPort(completer.complete, timeout: _ms * 500);
    p.send(42);
    return completer.future.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('Timeout', () {
    final completer = Completer.sync();
    singleCallbackPort(completer.complete,
        timeout: _ms * 100, timeoutValue: 37);
    return completer.future.then<Null>((v) {
      expect(v, 37);
    });
  });

  test('TimeoutFirst', () {
    final completer = Completer.sync();
    final p = singleCallbackPort(completer.complete,
        timeout: _ms * 100, timeoutValue: 37);
    Timer(_ms * 500, () => p.send(42));
    return completer.future.then<Null>((v) {
      expect(v, 37);
    });
  });
}

void testSingleCompletePort() {
  test('Value', () {
    final completer = Completer.sync();
    final p = singleCompletePort(completer);
    p.send(42);
    return completer.future.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('ValueCallback', () {
    final completer = Completer.sync();
    final p = singleCompletePort(completer, callback: (dynamic v) {
      expect(42, v);
      return 87;
    });
    p.send(42);
    return completer.future.then<Null>((v) {
      expect(v, 87);
    });
  });

  test('ValueCallbackFuture', () {
    final completer = Completer.sync();
    final p = singleCompletePort(completer, callback: (dynamic v) {
      expect(42, v);
      return Future.delayed(_ms * 500, () => 88);
    });
    p.send(42);
    return completer.future.then<Null>((v) {
      expect(v, 88);
    });
  });

  test('ValueCallbackThrows', () {
    final completer = Completer.sync();
    final p =
        singleCompletePort(completer, callback: (dynamic v) {
      expect(42, v);
      throw 89;
    });
    p.send(42);
    return completer.future.then<Null>((v) async {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 89);
    });
  });

  test('ValueCallbackThrowsFuture', () {
    final completer = Completer.sync();
    final p = singleCompletePort(completer, callback: (dynamic v) {
      expect(42, v);
      return Future.error(90);
    });
    p.send(42);
    return completer.future.then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 90);
    });
  });

  test('FirstValue', () {
    final completer = Completer.sync();
    final p = singleCompletePort(completer);
    p.send(42);
    p.send(37);
    return completer.future.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('FirstValueCallback', () {
    final completer = Completer.sync();
    final p = singleCompletePort(completer, callback: (v) {
      expect(v, 42);
      return 87;
    });
    p.send(42);
    p.send(37);
    return completer.future.then<Null>((v) {
      expect(v, 87);
    });
  });

  test('ValueBeforeTimeout', () {
    final completer = Completer.sync();
    final p = singleCompletePort(completer, timeout: _ms * 500);
    p.send(42);
    return completer.future.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('Timeout', () {
    final completer = Completer.sync();
    singleCompletePort(completer, timeout: _ms * 100);
    return completer.future.then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is TimeoutException, isTrue);
    });
  });

  test('TimeoutCallback', () {
    final completer = Completer.sync();
    singleCompletePort(completer, timeout: _ms * 100, onTimeout: () => 87);
    return completer.future.then<Null>((v) {
      expect(v, 87);
    });
  });

  test('TimeoutCallbackThrows', () {
    final completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100, onTimeout: () => throw 91);
    return completer.future.then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 91);
    });
  });

  test('TimeoutCallbackFuture', () {
    final completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100, onTimeout: () => Future.value(87));
    return completer.future.then<Null>((v) {
      expect(v, 87);
    });
  });

  test('TimeoutCallbackThrowsFuture', () {
    final completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100, onTimeout: () => Future.error(92));
    return completer.future.then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 92);
    });
  });

  test('TimeoutCallbackSLow', () {
    final completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100,
        onTimeout: () => Future.delayed(_ms * 500, () => 87));
    return completer.future.then<Null>((v) {
      expect(v, 87);
    });
  });

  test('TimeoutCallbackThrowsSlow', () {
    final completer = Completer.sync();
    singleCompletePort(completer,
        timeout: _ms * 100,
        onTimeout: () => Future.delayed(_ms * 500, () => throw 87));
    return completer.future.then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 87);
    });
  });

  test('TimeoutFirst', () {
    final completer = Completer.sync();
    final p =
        singleCompletePort(completer, timeout: _ms * 100, onTimeout: () => 37);
    Timer(_ms * 500, () => p.send(42));
    return completer.future.then<Null>((v) {
      expect(v, 37);
    });
  });

  test('TimeoutFirst with valid null', () {
    final completer = Completer<int?>.sync();
    final p = singleCompletePort(completer,
        timeout: _ms * 100, onTimeout: () => null);
    Timer(_ms * 500, () => p.send(42));
    return expectLater(completer.future, completion(null));
  });

  test('TimeoutFirst with invalid null', () {
    final completer = Completer<int>.sync();

    /// example of incomplete generic parameters promotion.
    /// same code with [singleCompletePort<int, dynamic>] is a compile time error
    final p = singleCompletePort(
      completer,
      timeout: _ms * 100,
      onTimeout: () => null,
    );
    Timer(_ms * 500, () => p.send(42));
    return expectLater(completer.future, throwsA(isA<TypeError>()));
  });
}

void testSingleResponseFuture() {
  test('FutureValue', () {
    return singleResponseFuture((SendPort p) {
      p.send(42);
    }).then<Null>((v) {
      expect(v, 42);
    });
  });

  test('FutureValueWithoutTimeout', () {
    return singleResponseFutureWithoutTimeout<int>((SendPort p) {
      p.send(42);
    }).then<Null>((v) {
      expect(v, 42);
    });
  });

  test('FutureValueWithoutTimeout valid null', () {
    return singleResponseFutureWithoutTimeout<int?>((SendPort p) {
      p.send(null);
    }).then<Null>((v) {
      expect(v, null);
    });
  });

  test('FutureValueWithoutTimeout invalid null', () {
    return expectLater(singleResponseFutureWithoutTimeout<int>((SendPort p) {
      p.send(null);
    }), throwsA(isA<TypeError>()));
  });

  test('FutureValueFirst', () {
    return singleResponseFuture((SendPort p) {
      p.send(42);
      p.send(37);
    }).then<Null>((v) {
      expect(v, 42);
    });
  });

  test('FutureError', () {
    return singleResponseFuture((SendPort p) {
      throw 93;
    }).then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e, 93);
    });
  });

  test('FutureTimeout', () {
    return singleResponseFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100)
        .then<Null>((v) {
      expect(v, null);
    });
  });

  test('FutureTimeoutValue', () {
    return singleResponseFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100, timeoutValue: 42)
        .then<Null>((int? v) {
      expect(v, 42);
    });
  });

  test('FutureTimeoutValue with valid null timeoutValue', () {
    return singleResponseFutureWithTimeout((SendPort p) {
      // no-op.
    }, timeout: _ms * 100, timeoutValue: null)
        .then<Null>((int? v) {
      expect(v, null);
    });
  });

  test('FutureTimeoutValue with non-null timeoutValue', () {
    return singleResponseFutureWithTimeout((SendPort p) {
      // no-op.
    }, timeout: _ms * 100, timeoutValue: 42)
        .then<Null>((int v) {
      expect(v, 42);
    });
  });
}

void testSingleResultFuture() {
  test('Value', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.value(42), p);
    }).then<Null>((v) {
      expect(v, 42);
    });
  });

  test('ValueFirst', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.value(42), p);
      sendFutureResult(Future.value(37), p);
    }).then<Null>((v) {
      expect(v, 42);
    });
  });

  test('Error', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.error(94), p);
    }).then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test('ErrorFirst', () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(Future.error(95), p);
      sendFutureResult(Future.error(96), p);
    }).then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test('Error', () {
    return singleResultFuture((SendPort p) {
      throw 93;
    }).then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test('Timeout', () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100)
        .then<Null>((v) {
      fail('unreachable');
    }, onError: (e, s) {
      expect(e is TimeoutException, isTrue);
    });
  });

  test('TimeoutValue', () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: _ms * 100, onTimeout: () => 42).then<Null>((v) {
      expect(v, 42);
    });
  });

  test('TimeoutError', () {
    return singleResultFuture((SendPort p) {
      return null;
    }, timeout: _ms * 100, onTimeout: () => throw 97).then<Null>((v) {
      expect(v, 42);
    }, onError: (e, s) {
      expect(e, 97);
    });
  });
}

void testSingleResponseChannel() {
  test('Value', () {
    final channel = SingleResponseChannel();
    channel.port.send(42);
    return channel.result.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('ValueFirst', () {
    final channel = SingleResponseChannel();
    channel.port.send(42);
    channel.port.send(37);
    return channel.result.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('ValueCallback', () {
    final channel = SingleResponseChannel(callback: ((v) => 2 * (v as num)));
    channel.port.send(42);
    return channel.result.then<Null>((v) {
      expect(v, 84);
    });
  });

  test('ErrorCallback', () {
    final channel = SingleResponseChannel(callback: ((v) => throw 42));
    channel.port.send(37);
    return channel.result.then<Null>((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });

  test('AsyncValueCallback', () {
    final channel =
        SingleResponseChannel(callback: ((v) => Future.value(2 * (v as num))));
    channel.port.send(42);
    return channel.result.then<Null>((v) {
      expect(v, 84);
    });
  });

  test('AsyncErrorCallback', () {
    final channel = SingleResponseChannel(callback: ((v) => Future.error(42)));
    channel.port.send(37);
    return channel.result.then<Null>((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });

  test('Timeout', () {
    final channel = SingleResponseChannel(timeout: _ms * 100);
    return channel.result.then<Null>((v) {
      expect(v, null);
    });
  });

  test('TimeoutThrow', () {
    final channel =
        SingleResponseChannel(timeout: _ms * 100, throwOnTimeout: true);
    return channel.result.then<Null>((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v is TimeoutException, isTrue);
    });
  });

  test('TimeoutThrowOnTimeoutAndValue', () {
    final channel = SingleResponseChannel(
        timeout: _ms * 100,
        throwOnTimeout: true,
        onTimeout: () => 42,
        timeoutValue: 42);
    return channel.result.then<Null>((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v is TimeoutException, isTrue);
    });
  });

  test('TimeoutOnTimeout', () {
    final channel =
        SingleResponseChannel(timeout: _ms * 100, onTimeout: () => 42);
    return channel.result.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutAndValue', () {
    final channel = SingleResponseChannel(
        timeout: _ms * 100, onTimeout: () => 42, timeoutValue: 37);
    return channel.result.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('TimeoutValue', () {
    final channel = SingleResponseChannel(timeout: _ms * 100, timeoutValue: 42);
    return channel.result.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutError', () {
    final channel =
        SingleResponseChannel(timeout: _ms * 100, onTimeout: () => throw 42);
    return channel.result.then<Null>((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutAsync', () {
    final channel = SingleResponseChannel(
        timeout: _ms * 100, onTimeout: () => Future.value(42));
    return channel.result.then<Null>((v) {
      expect(v, 42);
    });
  });

  test('TimeoutOnTimeoutAsyncError', () {
    final channel = SingleResponseChannel(
        timeout: _ms * 100, onTimeout: () => Future.error(42));
    return channel.result.then<Null>((v) {
      fail('unreachable');
    }, onError: (v, s) {
      expect(v, 42);
    });
  });
}
