// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Utility functions for setting up ports and sending data.
 *
 * This library contains a number of functions that handle the
 * boiler-plate of setting up a receive port and receiving a
 * single message on the port.
 *
 * There are different functions that offer different ways to
 * handle the incoming message.
 *
 * The simplest function, [singleCallbackPort], takes a callback
 * and returns a port, and then calls the callback for the first
 * message sent on the port.
 *
 * Other functions intercept the returned value and either
 * does something with it, or puts it into a [Future] or [Completer].
 */
library dart.pkg.isolate.ports;

import "dart:isolate";
import "dart:async";
import "src/lists.dart";

/**
 * Create a [SendPort] that accepts only one message.
 *
 * The [callback] function is called once, with the first message
 * received by the receive port.
 * All futher messages are ignored.
 *
 * If [timeout] is supplied, it is used as a limit on how
 * long it can take before the message is received. If a
 * message isn't received in time, the `callback` function
 * is called once with the [timeoutValue] instead.
 *
 * Returns the `SendPort` expecting the single message.
 *
 * Equivalent to:
 *
 *     (new ReceivePort()
 *         ..first.timeout(duration, () => timeoutValue).then(callback))
 *         .sendPort
 */
SendPort singleCallbackPort(void callback(response),
                            {Duration timeout,
                             var timeoutValue}) {
  RawReceivePort responsePort = new RawReceivePort();
  Zone zone = Zone.current;
  callback = zone.registerUnaryCallback(callback);
  var timer;
  responsePort.handler = (response) {
    responsePort.close();
    if (timer != null) timer.cancel();
    zone.runUnary(callback, response);
  };
  if (timeout != null) {
    timer = new Timer(timeout, () {
      responsePort.close();
      callback(timeoutValue);
    });
  }
  return responsePort.sendPort;
}

/**
 * Create a [SendPort] that accepts only one message.
 *
 * When the first message is received, the [callback] function is
 * called with the message as argument,
 * and the [completer] is completed with the result of that call.
 * All further messages are ignored.
 *
 * If `callback` is omitted, it defaults to an identity function.
 * The `callback` call may return a future, and the completer will
 * wait for that future to complete.
 *
 * If [timeout] is supplied, it is used as a limit on how
 * long it can take before the message is received. If a
 * message isn't received in time, the [onTimeout] is called,
 * and `completer` is completed with the result of that call
 * instead.
 * The [callback] function will not be interrupted by the time-out,
 * as long as the initial message is received in time.
 * If `onTimeout` is omitted, it defaults to completing the `completer` with
 * a [TimeoutException].
 *
 * The [completer] may be a synchronous completer. It is only
 * completed in response to another event, either a port message or a timer.
 *
 * Returns the `SendPort` expecting the single message.
 */
SendPort singleCompletePort(Completer completer,
                            {callback(message),
                             Duration timeout,
                             onTimeout()}) {
  if (callback == null && timeout == null) {
    return singleCallbackPort(completer.complete);
  }
  RawReceivePort responsePort = new RawReceivePort();
  var timer;
  if (callback == null) {
    responsePort.handler = (response) {
      responsePort.close();
      if (timer != null) timer.cancel();
      completer.complete(response);
    };
  } else {
    Zone zone = Zone.current;
    Function action = zone.registerUnaryCallback((response) {
      completer.complete(new Future.sync(() => callback(response)));
    });
    responsePort.handler = (response) {
      responsePort.close();
      if (timer != null) timer.cancel();
      zone.runUnary(action, response);
    };
  }
  if (timeout != null) {
    timer = new Timer(timeout, () {
      responsePort.close();
      if (onTimeout != null) {
        completer.complete(new Future.sync(onTimeout));
      } else {
        completer.completeError(new TimeoutException("Future not completed",
                                                     timeout));
      }
    });
  }
  return responsePort.sendPort;
}

/**
 * Creates a [Future], and a [SendPort] that can be used to complete that
 * future.
 *
 * Calls [action] with the response `SendPort`, then waits for someone
 * to send a value on that port
 * The returned `Future` is completed with the value sent on the port.
 *
 * If [action] throws, which it shouldn't,
 * the returned future is completed with that error.
 * Any return value of `action` is ignored, and if it is asynchronous,
 * it should handle its own errors.
 *
 * If [timeout] is supplied, it is used as a limit on how
 * long it can take before the message is received. If a
 * message isn't received in time, the [timeoutValue] used
 * as the returned future's value instead.
 *
 * If you want a timeout on the returned future, it's recommended to
 * use the [timeout] parameter, and not [Future.timeout] on the result.
 * The `Future` method won't be able to close the underlying [ReceivePort].
 */
Future singleResponseFuture(void action(SendPort responsePort),
                            {Duration timeout,
                             var timeoutValue}) {
  Completer completer = new Completer.sync();
  RawReceivePort responsePort = new RawReceivePort();
  Timer timer;
  Zone zone = Zone.current;
  responsePort.handler = (v) {
    responsePort.close();
    if (timer != null) timer.cancel();
    zone.run(() {
      completer.complete(v);
    });
  };
  if (timeout != null) {
    timer = new Timer(timeout, () {
      responsePort.close();
      completer.complete(timeoutValue);
    });
  }
  try {
    action(responsePort.sendPort);
  } catch (e, s) {
    responsePort.close();
    if (timer != null) timer.cancel();
    // Delay completion because completer is sync.
    scheduleMicrotask(() { completer.completeError(e, s); });
  }
  return completer.future;
}


/**
 * Send the result of a future, either value or error, as a message.
 *
 * The result of [future] is sent on [resultPort] in a form expected by
 * either [receiveFutureResult], [completeFutureResult], or
 * by the port of [singleResultFuture].
 */
void sendFutureResult(Future future, SendPort resultPort) {
  future.then((v) { resultPort.send(list1(v)); },
              onError: (e, s) { resultPort.send(list2("$e", "$s")); });
}


/**
 * Creates a [Future], and a [SendPort] that can be used to complete that
 * future.
 *
 * Calls [action] with the response `SendPort`, then waits for someone
 * to send a future result on that port using [sendFutureResult].
 * The returned `Future` is completed with the future result sent on the port.
 *
 * If [action] throws, which it shouldn't,
 * the returned future is completed with that error,
 * unless someone manages to send a message on the port before `action` throws.
 *
 * If [timeout] is supplied, it is used as a limit on how
 * long it can take before the message is received. If a
 * message isn't received in time, the [onTimeout] is called,
 * and the future is completed with the result of that call
 * instead.
 * If `onTimeout` is omitted, it defaults to throwing
 * a [TimeoutException].
 */
Future singleResultFuture(void action(SendPort responsePort),
                          {Duration timeout,
                           onTimeout()}) {
  Completer completer = new Completer.sync();
  SendPort port = singleCompletePort(completer,
                                     callback: receiveFutureResult,
                                     timeout: timeout,
                                     onTimeout: onTimeout);
  try {
    action(port);
  } catch (e, s) {
    // This should not happen.
    sendFutureResult(new Future.error(e, s), port);
  }
  return completer.future;
}

/**
 * Completes a completer with a message created by [sendFutureResult]
 *
 * The [response] must be a message on the format sent by [sendFutureResult].
 */
void completeFutureResult(var response, Completer completer) {
  if (response.length == 2) {
    var error = new RemoteError(response[0], response[1]);
    completer.completeError(error, error.stackTrace);
  } else {
    var result = response[0];
    completer.complete(result);
  }
}


/**
 * Convertes a received message created by [sendFutureResult] to a future
 * result.
 *
 * The [response] must be a message on the format sent by [sendFutureResult].
 */
Future receiveFutureResult(var response) {
  if (response.length == 2) {
    var error = new RemoteError(response[0], response[1]);
    return new Future.error(error, error.stackTrace);
  }
  var result = response[0];
  return new Future.value(result);
}
