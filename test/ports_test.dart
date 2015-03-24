// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart.pkg.isolate.isolaterunner_test;

import 'dart:async';
import 'dart:isolate';

import 'package:isolate/ports.dart';
import 'package:unittest/unittest.dart';

const Duration MS = const Duration(milliseconds: 1);

main() {
  testSingleCallbackPort();
  testSingleCompletePort();
  testSingleResponseFuture();
  testSingleResultFuture();
  testSingleResponseChannel();
}

void testSingleCallbackPort() {
  test("singleCallbackValue", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCallbackPort(completer.complete);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test("singleCallbackFirstValue", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCallbackPort(completer.complete);
    p.send(42);
    p.send(37);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });
  test("singleCallbackValue", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCallbackPort(completer.complete);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test("singleCallbackValueBeforeTimeout", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCallbackPort(completer.complete, timeout: MS * 500);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test("singleCallbackTimeout", () {
    Completer completer = new Completer.sync();
    singleCallbackPort(completer.complete, timeout: MS * 100, timeoutValue: 37);
    return completer.future.then((v) {
      expect(v, 37);
    });
  });

  test("singleCallbackTimeoutFirst", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCallbackPort(completer.complete,
                                    timeout: MS * 100,
                                    timeoutValue: 37);
    new Timer(MS * 500, () => p.send(42));
    return completer.future.then((v) {
      expect(v, 37);
    });
  });
}


void testSingleCompletePort() {
  test("singleCompleteValue", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test("singleCompleteValueCallback", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      return 87;
    });
    p.send(42);
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test("singleCompleteValueCallbackFuture", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      return new Future.delayed(MS * 500,
                                () => 88);
    });
    p.send(42);
    return completer.future.then((v) {
      expect(v, 88);
    });
  });

  test("singleCompleteValueCallbackThrows", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      throw 89;
    });
    p.send(42);
    return completer.future.then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e, 89);
    });
  });

  test("singleCompleteValueCallbackThrowsFuture", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer, callback: (v) {
      expect(42, v);
      return new Future.error(90);
    });
    p.send(42);
    return completer.future.then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e, 90);
    });
  });

  test("singleCompleteFirstValue", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer);
    p.send(42);
    p.send(37);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test("singleCompleteFirstValueCallback", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer, callback: (v) {
       expect(v, 42);
       return 87;
     });
    p.send(42);
    p.send(37);
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test("singleCompleteValueBeforeTimeout", () {
    Completer completer = new Completer.sync();
    SendPort p = singleCompletePort(completer, timeout: MS * 500);
    p.send(42);
    return completer.future.then((v) {
      expect(v, 42);
    });
  });

  test("singleCompleteTimeout", () {
    Completer completer = new Completer.sync();
    singleCompletePort(completer, timeout: MS * 100);
    return completer.future.then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e is TimeoutException, isTrue);
    });
  });

  test("singleCompleteTimeoutCallback", () {
    Completer completer = new Completer.sync();
    singleCompletePort(completer, timeout: MS * 100, onTimeout: () => 87);
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test("singleCompleteTimeoutCallbackThrows", () {
    Completer completer = new Completer.sync();
    singleCompletePort(completer, timeout: MS * 100, onTimeout: () => throw 91);
    return completer.future.then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e, 91);
    });
  });

  test("singleCompleteTimeoutCallbackFuture", () {
    Completer completer = new Completer.sync();
    singleCompletePort(completer,
                       timeout: MS * 100,
                       onTimeout: () => new Future.value(87));
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test("singleCompleteTimeoutCallbackThrowsFuture", () {
    Completer completer = new Completer.sync();
    singleCompletePort(completer,
                       timeout: MS * 100,
                       onTimeout: () => new Future.error(92));
    return completer.future.then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e, 92);
    });
  });

  test("singleCompleteTimeoutCallbackSLow", () {
    Completer completer = new Completer.sync();
    singleCompletePort(
        completer,
        timeout: MS * 100,
        onTimeout: () => new Future.delayed(MS * 500, () => 87));
    return completer.future.then((v) {
      expect(v, 87);
    });
  });

  test("singleCompleteTimeoutCallbackThrowsSlow", () {
    Completer completer = new Completer.sync();
    singleCompletePort(
        completer,
        timeout: MS * 100,
        onTimeout: () => new Future.delayed(MS * 500, () => throw 87));
    return completer.future.then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e, 87);
    });
  });

  test("singleCompleteTimeoutFirst", () {
    Completer completer = new Completer.sync();
    SendPort p =
        singleCompletePort(completer, timeout: MS * 100, onTimeout: () => 37);
    new Timer(MS * 500, () => p.send(42));
    return completer.future.then((v) {
      expect(v, 37);
    });
  });
}

void testSingleResponseFuture() {
  test("singleResponseFutureValue", () {
    return singleResponseFuture((SendPort p) {
      p.send(42);
    }).then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseFutureValueFirst", () {
    return singleResponseFuture((SendPort p) {
      p.send(42);
      p.send(37);
    }).then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseFutureError", () {
    return singleResponseFuture((SendPort p) {
      throw 93;
    }).then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e, 93);
    });
  });

  test("singleResponseFutureTimeout", () {
    return singleResponseFuture((SendPort p) {
      // no-op.
    }, timeout: MS * 100).then((v) {
      expect(v, null);
    });
  });

  test("singleResponseFutureTimeoutValue", () {
    return singleResponseFuture((SendPort p) {
      // no-op.
    }, timeout: MS * 100, timeoutValue: 42).then((v) {
      expect(v, 42);
    });
  });
}

void testSingleResultFuture() {
  test("singleResultFutureValue", () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(new Future.value(42), p);
    }).then((v) {
      expect(v, 42);
    });
  });

  test("singleResultFutureValueFirst", () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(new Future.value(42), p);
      sendFutureResult(new Future.value(37), p);
    }).then((v) {
      expect(v, 42);
    });
  });

  test("singleResultFutureError", () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(new Future.error(94), p);
    }).then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test("singleResultFutureErrorFirst", () {
    return singleResultFuture((SendPort p) {
      sendFutureResult(new Future.error(95), p);
      sendFutureResult(new Future.error(96), p);
    }).then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test("singleResultFutureError", () {
    return singleResultFuture((SendPort p) {
      throw 93;
    }).then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e is RemoteError, isTrue);
    });
  });

  test("singleResultFutureTimeout", () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: MS * 100).then((v) {
      fail("unreachable");
    }, onError: (e, s) {
      expect(e is TimeoutException, isTrue);
    });
  });

  test("singleResultFutureTimeoutValue", () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: MS * 100, onTimeout: () => 42).then((v) {
      expect(v, 42);
    });
  });

  test("singleResultFutureTimeoutError", () {
    return singleResultFuture((SendPort p) {
      // no-op.
    }, timeout: MS * 100, onTimeout: () => throw 97).then((v) {
      expect(v, 42);
    }, onError: (e, s) {
      expect(e, 97);
    });
  });
}

void testSingleResponseChannel() {
   test("singleResponseChannelValue", () {
    var channel = new SingleResponseChannel();
    channel.port.send(42);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseChannelValueFirst", () {
    var channel = new SingleResponseChannel();
    channel.port.send(42);
    channel.port.send(37);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseChannelValueCallback", () {
    var channel = new SingleResponseChannel(callback: (v) => v * 2);
    channel.port.send(42);
    return channel.result.then((v) {
      expect(v, 84);
    });
  });

  test("singleResponseChannelErrorCallback", () {
    var channel = new SingleResponseChannel(callback: (v) => throw 42);
    channel.port.send(37);
    return channel.result.then((v) { fail("unreachable"); },
                               onError: (v, s) {
                                 expect(v, 42);
                               });
  });

  test("singleResponseChannelAsyncValueCallback", () {
    var channel = new SingleResponseChannel(
                          callback: (v) => new Future.value(v * 2));
    channel.port.send(42);
    return channel.result.then((v) {
      expect(v, 84);
    });
  });

  test("singleResponseChannelAsyncErrorCallback", () {
    var channel = new SingleResponseChannel(callback:
                                                (v) => new Future.error(42));
    channel.port.send(37);
    return channel.result.then((v) { fail("unreachable"); },
                               onError: (v, s) {
                                 expect(v, 42);
                               });
  });

  test("singleResponseChannelTimeout", () {
    var channel = new SingleResponseChannel(timeout: MS * 100);
    return channel.result.then((v) {
      expect(v, null);
    });
  });

  test("singleResponseChannelTimeoutThrow", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            throwOnTimeout: true);
    return channel.result.then((v) { fail("unreachable"); },
                               onError: (v, s) {
                                 expect(v is TimeoutException, isTrue);
                               });
  });

  test("singleResponseChannelTimeoutThrowOnTimeoutAndValue", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            throwOnTimeout: true,
                                            onTimeout: () => 42,
                                            timeoutValue: 42);
    return channel.result.then((v) { fail("unreachable"); },
                               onError: (v, s) {
                                 expect(v is TimeoutException, isTrue);
                               });
  });

  test("singleResponseChannelTimeoutOnTimeout", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            onTimeout: () => 42);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseChannelTimeoutOnTimeoutAndValue", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            onTimeout: () => 42,
                                            timeoutValue: 37);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseChannelTimeoutValue", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            timeoutValue: 42);
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseChannelTimeoutOnTimeoutError", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            onTimeout: () => throw 42);
    return channel.result.then((v) { fail("unreachable"); },
                               onError: (v, s) {
                                 expect(v, 42);
                               });
  });

  test("singleResponseChannelTimeoutOnTimeoutAsync", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            onTimeout:
                                                () => new Future.value(42));
    return channel.result.then((v) {
      expect(v, 42);
    });
  });

  test("singleResponseChannelTimeoutOnTimeoutAsyncError", () {
    var channel = new SingleResponseChannel(timeout: MS * 100,
                                            onTimeout:
                                                () => new Future.error(42));
    return channel.result.then((v) { fail("unreachable"); },
                               onError: (v, s) {
                                 expect(v, 42);
                               });
  });
}
