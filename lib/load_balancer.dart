// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A load-balancing runner pool.
library isolate.load_balancer;

import 'dart:async' show Future, FutureOr;

import 'package:collection/collection.dart';

import 'runner.dart';
import 'src/errors.dart';
import 'src/util.dart';

/// A pool of runners, ordered by load.
///
/// Keeps a pool of runners,
/// and allows running function through the runner with the lowest current load.
class LoadBalancer implements Runner {
  // A heap-based priority queue of entries, prioritized by `load`.
  // Each entry has its own entry in the queue, for faster update.
  PriorityQueue<_LoadBalancerEntry> _queue;

  // Whether [stop] has been called.
  Future<void>? _stopFuture;

  /// Create a load balancer backed by the [Runner]s of [runners].
  LoadBalancer(Iterable<Runner> runners) : this._(_createEntries(runners));

  LoadBalancer._(PriorityQueue<_LoadBalancerEntry> entries) : _queue = entries;

  /// The number of runners currently in the pool.
  int get length => _queue.length;

  /// Asynchronously create [size] runners and create a `LoadBalancer` of those.
  ///
  /// This is a helper function that makes it easy to create a `LoadBalancer`
  /// with asynchronously created runners, for example:
  /// ```dart
  /// var isolatePool = LoadBalancer.create(10, IsolateRunner.spawn);
  /// ```
  static Future<LoadBalancer> create(
      int size, Future<Runner> Function() createRunner) {
    return Future.wait(Iterable.generate(size, (_) => createRunner()),
        cleanUp: (Runner runner) {
      runner.close();
    }).then((runners) => LoadBalancer(runners));
  }

  static PriorityQueue<_LoadBalancerEntry> _createEntries(
          Iterable<Runner> runners) =>
      PriorityQueue<_LoadBalancerEntry>()
        ..addAll(runners.map((runner) => _LoadBalancerEntry(runner)));

  /// Execute the command in the currently least loaded isolate.
  ///
  /// The optional [load] parameter represents the load that the command
  /// is causing on the isolate where it runs.
  /// The number has no fixed meaning, but should be seen as relative to
  /// other commands run in the same load balancer.
  /// The `load` must not be negative.
  ///
  /// If [timeout] and [onTimeout] are provided, they are forwarded to
  /// the runner running the function, which will handle a timeout
  /// as normal. If the runners are running in other isolates, then
  /// the [onTimeout] function must be a constant function.
  @override
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, P argument,
      {Duration? timeout, FutureOr<R> Function()? onTimeout, int load = 100}) {
    RangeError.checkNotNegative(load, 'load');
    final entry = _queue.removeFirst();
    entry.load += 1;
    _queue.add(entry);
    return entry.run(this, load, function, argument, timeout, onTimeout);
  }

  /// Execute the same function in the least loaded [count] isolates.
  ///
  /// This guarantees that the function isn't run twice in the same isolate,
  /// so `count` is not allowed to exceed [length].
  ///
  /// The optional [load] parameter represents the load that the command
  /// is causing on the isolate where it runs.
  /// The number has no fixed meaning, but should be seen as relative to
  /// other commands run in the same load balancer.
  /// The `load` must not be negative.
  ///
  /// If [timeout] and [onTimeout] are provided, they are forwarded to
  /// the runners running the function, which will handle any timeouts
  /// as normal.
  List<FutureOr<R>> runMultiple<R, P>(
      int count, FutureOr<R> Function(P argument) function, P argument,
      {Duration? timeout, FutureOr<R> Function()? onTimeout, int load = 100}) {
    RangeError.checkValueInInterval(count, 1, length, 'count');
    RangeError.checkNotNegative(load, 'load');
    if (count == 1) {
      return List<FutureOr<R>>.filled(
          1,
          run(function, argument,
              load: load, timeout: timeout, onTimeout: onTimeout));
    }
    final placeholderFuture = Future<R>.value();
    final result = List<FutureOr<R>>.filled(count, placeholderFuture);
    if (count == length) {
      // No need to change the order of entries in the queue.
      _queue.unorderedElements.mapIndexed((index, entry) {
        entry.load += load;
        result[index] =
            entry.run(this, load, function, argument, timeout, onTimeout);
      }).forEach(ignore);
    } else {
      // Remove the [count] least loaded services and run the
      // command on each, then add them back to the queue.
      // This avoids running the same command twice in the same
      // isolate.
      // We can't assume that the first [count] entries in the
      // heap list are the least loaded.
      var entries = List<_LoadBalancerEntry>.generate(
        count,
        (_) => _queue.removeFirst(),
        growable: false,
      );
      for (var i = 0; i < count; i++) {
        var entry = entries[i];
        entry.load += load;
        _queue.add(entry);
        result[i] =
            entry.run(this, load, function, argument, timeout, onTimeout);
      }
    }
    return result;
  }

  @override
  Future<void> close() {
    var stopFuture = _stopFuture;
    if (stopFuture != null) return stopFuture;
    _stopFuture = (stopFuture =
        MultiError.waitUnordered(_queue.removeAll().map((e) => e.close()))
            .then(ignore));
    return stopFuture;
  }
}

class _LoadBalancerEntry implements Comparable<_LoadBalancerEntry> {
  // The current load on the isolate.
  int load = 0;

  // The service used to send commands to the other isolate.
  Runner runner;

  _LoadBalancerEntry(Runner runner) : runner = runner;

  Future<R> run<R, P>(
      LoadBalancer balancer,
      int load,
      FutureOr<R> Function(P argument) function,
      P argument,
      Duration? timeout,
      FutureOr<R> Function()? onTimeout) {
    return runner
        .run<R, P>(function, argument, timeout: timeout, onTimeout: onTimeout)
        .whenComplete(() {
      balancer._queue.remove(this);
      load -= 1;
      balancer._queue.add(this);
    });
  }

  Future? close() => runner.close();

  @override
  int compareTo(_LoadBalancerEntry other) => load - other.load;
}
