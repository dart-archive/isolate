// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utility functions for setting up ports and sending data.
///
/// This library contains a number of functions that handle the
/// boiler-plate of setting up a receive port and receiving a
/// single message on the port.
///
/// There are different functions that offer different ways to
/// handle the incoming message.
///
/// The simplest function, [singleCallbackPort], takes a callback
/// and returns a port, and then calls the callback for the first
/// message sent on the port.
///
/// Other functions intercept the returned value and either
/// does something with it, or puts it into a [Future] or [Completer].
library isolate.ports;

import 'dart:async';
import 'dart:isolate';

import 'src/util.dart';

/// Create a [SendPort] that accepts only one message.
///
/// The [callback] function is called once, with the first message
/// received by the receive port.
/// All further messages are ignored.
///
/// If [timeout] is supplied, it is used as a limit on how
/// long it can take before the message is received. If a
/// message isn't received in time, the `callback` function
/// is called once with the [timeoutValue] instead.
///
/// If the received value is not a [T], it will cause an uncaught
/// asynchronous error in the current zone.
///
/// Returns the `SendPort` expecting the single message.
///
/// Equivalent to:
/// ```dart
/// (new ReceivePort()
///       ..first.timeout(duration, () => timeoutValue).then(callback))
///     .sendPort
/// ```
SendPort singleCallbackPort<P>(void Function(P response) callback,
    {Duration timeout, P timeoutValue}) {
  var responsePort = RawReceivePort();
  var zone = Zone.current;
  callback = zone.registerUnaryCallback(callback);
  Timer timer;
  responsePort.handler = (response) {
    responsePort.close();
    timer?.cancel();
    zone.runUnary(callback, response as P);
  };
  if (timeout != null) {
    timer = Timer(timeout, () {
      responsePort.close();
      callback(timeoutValue);
    });
  }
  return responsePort.sendPort;
}

/// Create a [SendPort] that accepts only one message.
///
/// When the first message is received, the [callback] function is
/// called with the message as argument,
/// and the [completer] is completed with the result of that call.
/// All further messages are ignored.
///
/// If `callback` is omitted, it defaults to an identity function.
/// The `callback` call may return a future, and the completer will
/// wait for that future to complete. If [callback] is omitted, the
/// message on the port must be an instance of [R].
///
/// If [timeout] is supplied, it is used as a limit on how
/// long it can take before the message is received. If a
/// message isn't received in time, the [onTimeout] is called,
/// and `completer` is completed with the result of that call
/// instead.
/// The [callback] function will not be interrupted by the time-out,
/// as long as the initial message is received in time.
/// If `onTimeout` is omitted, it defaults to completing the `completer` with
/// a [TimeoutException].
///
/// The [completer] may be a synchronous completer. It is only
/// completed in response to another event, either a port message or a timer.
///
/// Returns the `SendPort` expecting the single message.
SendPort singleCompletePort<R, P>(Completer<R> completer,
    {FutureOr<R> Function(P message) callback,
    Duration timeout,
    FutureOr<R> Function() onTimeout}) {
  if (callback == null && timeout == null) {
    return singleCallbackPort<Object>((response) {
      _castComplete<R>(completer, response);
    });
  }
  var responsePort = RawReceivePort();
  Timer timer;
  if (callback == null) {
    responsePort.handler = (response) {
      responsePort.close();
      timer?.cancel();
      _castComplete<R>(completer, response);
    };
  } else {
    var zone = Zone.current;
    var action = zone.registerUnaryCallback((response) {
      try {
        // Also catch it if callback throws.
        completer.complete(callback(response as P));
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    responsePort.handler = (response) {
      responsePort.close();
      timer?.cancel();
      zone.runUnary(action, response as P);
    };
  }
  if (timeout != null) {
    timer = Timer(timeout, () {
      responsePort.close();
      if (onTimeout != null) {
        completer.complete(Future.sync(onTimeout));
      } else {
        completer
            .completeError(TimeoutException('Future not completed', timeout));
      }
    });
  }
  return responsePort.sendPort;
}

/// Creates a [Future], and a [SendPort] that can be used to complete that
/// future.
///
/// Calls [action] with the response `SendPort`, then waits for someone
/// to send a value on that port
/// The returned `Future` is completed with the value sent on the port.
///
/// If [action] throws, which it shouldn't,
/// the returned future is completed with that error.
/// Any return value of `action` is ignored, and if it is asynchronous,
/// it should handle its own errors.
///
/// If [timeout] is supplied, it is used as a limit on how
/// long it can take before the message is received. If a
/// message isn't received in time, the [timeoutValue] used
/// as the returned future's value instead.
///
/// If you want a timeout on the returned future, it's recommended to
/// use the [timeout] parameter, and not [Future.timeout] on the result.
/// The `Future` method won't be able to close the underlying [ReceivePort].
Future<R> singleResponseFuture<R>(void Function(SendPort responsePort) action,
    {Duration timeout, R timeoutValue}) {
  var completer = Completer<R>.sync();
  var responsePort = RawReceivePort();
  Timer timer;
  var zone = Zone.current;
  responsePort.handler = (Object response) {
    responsePort.close();
    timer?.cancel();
    zone.run(() {
      _castComplete<R>(completer, response);
    });
  };
  if (timeout != null) {
    timer = Timer(timeout, () {
      responsePort.close();
      completer.complete(timeoutValue);
    });
  }
  try {
    action(responsePort.sendPort);
  } catch (error, stack) {
    responsePort.close();
    timer?.cancel();
    // Delay completion because completer is sync.
    scheduleMicrotask(() {
      completer.completeError(error, stack);
    });
  }
  return completer.future;
}

/// Send the result of a future, either value or error, as a message.
///
/// The result of [future] is sent on [resultPort] in a form expected by
/// either [receiveFutureResult], [completeFutureResult], or
/// by the port of [singleResultFuture].
void sendFutureResult(Future<Object> future, SendPort resultPort) {
  future.then((value) {
    resultPort.send(list1(value));
  }, onError: (error, stack) {
    resultPort.send(list2('$error', '$stack'));
  });
}

/// Creates a [Future], and a [SendPort] that can be used to complete that
/// future.
///
/// Calls [action] with the response `SendPort`, then waits for someone
/// to send a future result on that port using [sendFutureResult].
/// The returned `Future` is completed with the future result sent on the port.
///
/// If [action] throws, which it shouldn't,
/// the returned future is completed with that error,
/// unless someone manages to send a message on the port before `action` throws.
///
/// If [timeout] is supplied, it is used as a limit on how
/// long it can take before the message is received. If a
/// message isn't received in time, the [onTimeout] is called,
/// and the future is completed with the result of that call
/// instead.
/// If `onTimeout` is omitted, it defaults to throwing
/// a [TimeoutException].
Future<R> singleResultFuture<R>(void Function(SendPort responsePort) action,
    {Duration timeout, FutureOr<R> Function() onTimeout}) {
  var completer = Completer<R>.sync();
  var port = singleCompletePort<R, List<Object>>(completer,
      callback: receiveFutureResult, timeout: timeout, onTimeout: onTimeout);
  try {
    action(port);
  } catch (e, s) {
    // This should not happen.
    sendFutureResult(Future.error(e, s), port);
  }
  return completer.future;
}

/// Completes a completer with a message created by [sendFutureResult]
///
/// The [response] must be a message on the format sent by [sendFutureResult].
void completeFutureResult<R>(List<Object> response, Completer<R> completer) {
  if (response.length == 2) {
    var error = RemoteError(response[0], response[1]);
    completer.completeError(error, error.stackTrace);
  } else {
    R result = response[0];
    completer.complete(result);
  }
}

/// Converts a received message created by [sendFutureResult] to a future
/// result.
///
/// The [response] must be a message on the format sent by [sendFutureResult].
Future<R> receiveFutureResult<R>(List<Object> response) {
  if (response.length == 2) {
    var error = RemoteError(response[0], response[1]);
    return Future.error(error, error.stackTrace);
  }
  R result = response[0];
  return Future<R>.value(result);
}

/// A [Future] and a [SendPort] that can be used to complete the future.
///
/// The first value sent to [port] is used to complete the [result].
/// All following values sent to `port` are ignored.
class SingleResponseChannel<R> {
  final Zone _zone;
  final RawReceivePort _receivePort;
  final Completer<R> _completer;
  final Function _callback;
  Timer _timer;

  /// Creates a response channel.
  ///
  /// The [result] is completed with the first value sent to [port].
  ///
  /// If [callback] is provided, the value sent to [port] is first passed
  /// to `callback`, and the result of that is used to complete `result`.
  ///
  /// If [timeout] is provided, the future is completed after that
  /// duration if it hasn't received a value from the port earlier.
  /// If [throwOnTimeout] is true, the the future is completed with a
  /// [TimeoutException] as an error if it times out.
  /// Otherwise, if [onTimeout] is provided,
  /// the future is completed with the result of running `onTimeout()`.
  /// If `onTimeout` is not provided either,
  /// the future is completed with `timeoutValue`, which defaults to `null`.
  SingleResponseChannel(
      {FutureOr<R> Function(Null value) callback,
      Duration timeout,
      bool throwOnTimeout = false,
      FutureOr<R> Function() onTimeout,
      R timeoutValue})
      : _receivePort = RawReceivePort(),
        _completer = Completer<R>.sync(),
        _callback = callback,
        _zone = Zone.current {
    _receivePort.handler = _handleResponse;
    if (timeout != null) {
      _timer = Timer(timeout, () {
        // Executed as a timer event.
        _receivePort.close();
        if (!_completer.isCompleted) {
          if (throwOnTimeout) {
            _completer.completeError(
                TimeoutException('Timeout waiting for response', timeout));
          } else if (onTimeout != null) {
            _completer.complete(Future.sync(onTimeout));
          } else {
            _completer.complete(timeoutValue);
          }
        }
      });
    }
  }

  /// The port expecting a value that will complete [result].
  SendPort get port => _receivePort.sendPort;

  /// Future completed by the first value sent to [port].
  Future<R> get result => _completer.future;

  /// If the channel hasn't completed yet, interrupt it and complete the result.
  ///
  /// If the channel hasn't received a value yet, or timed out, it is stopped
  /// (like by a timeout) and the [SingleResponseChannel.result]
  /// is completed with [result].
  void interrupt([R result]) {
    _receivePort.close();
    _cancelTimer();
    if (!_completer.isCompleted) {
      // Not in event tail position, so complete the sync completer later.
      _completer.complete(Future.microtask(() => result));
    }
  }

  void _cancelTimer() {
    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }
  }

  void _handleResponse(v) {
    // Executed as a port event.
    _receivePort.close();
    _cancelTimer();
    if (_callback == null) {
      try {
        _completer.complete(v as R);
      } catch (e, s) {
        _completer.completeError(e, s);
      }
    } else {
      // The _handleResponse function is the handler of a RawReceivePort.
      // As such, it runs in the root zone.
      // The _callback should be run in the original zone, both because it's
      // what the user expects, and because it may create an error that needs
      // to be propagated to the original completer. If that completer was
      // created in a different error zone, an error from the root zone
      // would become uncaught.
      _zone.run(() {
        _completer.complete(Future.sync(() => _callback(v)));
      });
    }
  }
}

// Helper function that casts an object to a type and completes a
// corresponding completer, or completes with the error if the cast fails.
void _castComplete<R>(Completer<R> completer, Object value) {
  try {
    completer.complete(value as R);
  } catch (error, stack) {
    completer.completeError(error, stack);
  }
}
