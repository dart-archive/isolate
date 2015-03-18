// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart.pkg.isolate.sample.httpserver;

import "dart:io";
import "dart:async";
import "dart:isolate";
import "package:isolate/isolaterunner.dart";
import "package:isolate/runner.dart";
import "package:isolate/ports.dart";

typedef Future RemoteStop();

Future<RemoteStop> runHttpServer(
    Runner runner, ServerSocket socket, HttpListener listener) {
  return runner.run(_startHttpServer, new List(2)..[0] = socket.reference
                                                 ..[1] = listener)
               .then((SendPort stopPort) => () => _sendStop(stopPort));
}

Future _sendStop(SendPort stopPort) {
  return singleResponseFuture(stopPort.send);
}

Future<SendPort> _startHttpServer(List args) {
  ServerSocketReference ref = args[0];
  HttpListener listener = args[1];
  return ref.create().then((socket) {
    return listener.start(new HttpServer.listenOn(socket));
  }).then((_) {
    return singleCallbackPort((SendPort resultPort) {
      sendFutureResult(new Future.sync(listener.stop), resultPort);
    });
  });
}

/// An [HttpRequest] handler setup. Gets called when with the server, and
/// is told when to stop listening.
///
/// These callbacks allow the listener to set up handlers for HTTP requests.
/// The object should be sendable to an equivalent isolate.
abstract class HttpListener {
  Future start(HttpServer server);
  Future stop();
}

/// An [HttpListener] that sets itself up as an echo server.
///
/// Returns the message content plus an ID describing the isolate that
/// handled the request.
class EchoHttpListener implements HttpListener {
  StreamSubscription _subscription;
  static int _id = new Object().hashCode;
  SendPort _counter;

  EchoHttpListener(this._counter);

  start(HttpServer server) {
    print("Starting isolate $_id");
    _subscription = server.listen((HttpRequest request) {
      request.response.addStream(request).then((_) {
        _counter.send(null);
        print("Request to $_id");
        request.response.write("#$_id\n");
        var t0 = new DateTime.now().add(new Duration(seconds: 2));
        while (new DateTime.now().isBefore(t0));
        print("Response from $_id");
        request.response.close();
      });
    });
  }

  stop() {
    print("Stopping isolate $_id");
    _subscription.cancel();
    _subscription = null;
  }
}

main(args) {
  int port = 0;
  if (args.length > 0) {
    port = int.parse(args[0]);
  }
  RawReceivePort counter = new RawReceivePort();
  HttpListener listener = new EchoHttpListener(counter.sendPort);
  ServerSocket
    .bind(InternetAddress.ANY_IP_V6, port)
    .then((ServerSocket socket) {
      port = socket.port;
      return Future.wait(new Iterable.generate(5, (_) => IsolateRunner.spawn()),
                         cleanUp: (isolate) { isolate.close(); })
                   .then((List<IsolateRunner> isolates) {
                     return Future.wait(isolates.map((IsolateRunner isolate) {
                       return runHttpServer(isolate, socket, listener);
                     }), cleanUp: (server) { server.stop(); });
                   })
                   .then((stoppers) {
                     socket.close();
                     int count = 25;
                     counter.handler = (_) {
                       count--;
                       if (count == 0) {
                         stoppers.forEach((f) => f());
                         counter.close();
                       }
                     };
                     print("Server listening on port $port for 25 requests");
                     print("Test with:");
                     print("  ab -c10 -n 25  http://localhost:$port/");
                   });
  });
}
