// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A load-balancing runner pool.
library isolate.load_balancer;

import 'dart:async' show Future, FutureOr;

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
  List<_LoadBalancerEntry> _queue;

  // The number of entries currently in the queue.
  int _length;

  // Whether [stop] has been called.
  Future<void> _stopFuture;

  /// Create a load balancer backed by the [Runner]s of [runners].
  LoadBalancer(Iterable<Runner> runners) : this._(_createEntries(runners));

  LoadBalancer._(List<_LoadBalancerEntry> entries)
      : _queue = entries,
        _length = entries.length {
    for (var i = 0; i < _length; i++) {
      _queue[i].queueIndex = i;
    }
  }

  /// The number of runners currently in the pool.
  int get length => _length;

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

  static List<_LoadBalancerEntry> _createEntries(Iterable<Runner> runners) {
    var entries = runners.map((runner) => _LoadBalancerEntry(runner));
    return List<_LoadBalancerEntry>.from(entries, growable: false);
  }

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
  Future<R> run<R, P>(FutureOr<R> Function(P argument) function, argument,
      {Duration timeout, FutureOr<R> Function() onTimeout, int load = 100}) {
    RangeError.checkNotNegative(load, 'load');
    var entry = _first;
    _increaseLoad(entry, load);
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
  List<Future<R>> runMultiple<R, P>(
      int count, FutureOr<R> Function(P argument) function, P argument,
      {Duration timeout, FutureOr<R> Function() onTimeout, int load = 100}) {
    RangeError.checkValueInInterval(count, 1, _length, 'count');
    RangeError.checkNotNegative(load, 'load');
    if (count == 1) {
      return List<Future<R>>(1)
        ..[0] = run(function, argument,
            load: load, timeout: timeout, onTimeout: onTimeout);
    }
    var result = List<Future<R>>(count);
    if (count == _length) {
      // No need to change the order of entries in the queue.
      for (var i = 0; i < count; i++) {
        var entry = _queue[i];
        entry.load += load;
        result[i] =
            entry.run(this, load, function, argument, timeout, onTimeout);
      }
    } else {
      // Remove the [count] least loaded services and run the
      // command on each, then add them back to the queue.
      // This avoids running the same command twice in the same
      // isolate.
      // We can't assume that the first [count] entries in the
      // heap list are the least loaded.
      var entries = List<_LoadBalancerEntry>(count);
      for (var i = 0; i < count; i++) {
        entries[i] = _removeFirst();
      }
      for (var i = 0; i < count; i++) {
        var entry = entries[i];
        entry.load += load;
        _add(entry);
        result[i] =
            entry.run(this, load, function, argument, timeout, onTimeout);
      }
    }
    return result;
  }

  @override
  Future<void> close() {
    if (_stopFuture != null) return _stopFuture;
    _stopFuture =
        MultiError.waitUnordered(_queue.take(_length).map((e) => e.close()))
            .then(ignore);
    // Remove all entries.
    for (var i = 0; i < _length; i++) {
      _queue[i].queueIndex = -1;
    }
    _queue = null;
    _length = 0;
    return _stopFuture;
  }

  /// Place [element] in heap at [index] or above.
  ///
  /// Put element into the empty cell at `index`.
  /// While the `element` has higher priority than the
  /// parent, swap it with the parent.
  void _bubbleUp(_LoadBalancerEntry element, int index) {
    while (index > 0) {
      var parentIndex = (index - 1) ~/ 2;
      var parent = _queue[parentIndex];
      if (element.compareTo(parent) > 0) break;
      _queue[index] = parent;
      parent.queueIndex = index;
      index = parentIndex;
    }
    _queue[index] = element;
    element.queueIndex = index;
  }

  /// Place [element] in heap at [index] or above.
  ///
  /// Put element into the empty cell at `index`.
  /// While the `element` has lower priority than either child,
  /// swap it with the highest priority child.
  void _bubbleDown(_LoadBalancerEntry element, int index) {
    while (true) {
      var childIndex = index * 2 + 1; // Left child index.
      if (childIndex >= _length) break;
      var child = _queue[childIndex];
      var rightChildIndex = childIndex + 1;
      if (rightChildIndex < _length) {
        var rightChild = _queue[rightChildIndex];
        if (rightChild.compareTo(child) < 0) {
          childIndex = rightChildIndex;
          child = rightChild;
        }
      }
      if (element.compareTo(child) <= 0) break;
      _queue[index] = child;
      child.queueIndex = index;
      index = childIndex;
    }
    _queue[index] = element;
    element.queueIndex = index;
  }

  /// Removes the entry from the queue, but doesn't stop its service.
  ///
  /// The entry is expected to be either added back to the queue
  /// immediately or have its stop method called.
  void _remove(_LoadBalancerEntry entry) {
    var index = entry.queueIndex;
    if (index < 0) return;
    entry.queueIndex = -1;
    _length--;
    var replacement = _queue[_length];
    _queue[_length] = null;
    if (index < _length) {
      if (entry.compareTo(replacement) < 0) {
        _bubbleDown(replacement, index);
      } else {
        _bubbleUp(replacement, index);
      }
    }
  }

  /// Adds entry to the queue.
  void _add(_LoadBalancerEntry entry) {
    if (_stopFuture != null) throw StateError('LoadBalancer is stopped');
    assert(entry.queueIndex < 0);
    if (_queue.length == _length) {
      _grow();
    }
    var index = _length;
    _length = index + 1;
    _bubbleUp(entry, index);
  }

  void _increaseLoad(_LoadBalancerEntry entry, int load) {
    assert(load >= 0);
    entry.load += load;
    if (entry.inQueue) {
      _bubbleDown(entry, entry.queueIndex);
    }
  }

  void _decreaseLoad(_LoadBalancerEntry entry, int load) {
    assert(load >= 0);
    entry.load -= load;
    if (entry.inQueue) {
      _bubbleUp(entry, entry.queueIndex);
    }
  }

  void _grow() {
    var newQueue = List(_length * 2);
    newQueue.setRange(0, _length, _queue);
    _queue = newQueue;
  }

  _LoadBalancerEntry get _first {
    assert(_length > 0);
    return _queue[0];
  }

  _LoadBalancerEntry _removeFirst() {
    var result = _first;
    _remove(result);
    return result;
  }
}

class _LoadBalancerEntry implements Comparable<_LoadBalancerEntry> {
  // The current load on the isolate.
  int load = 0;
  // The current index in the heap-queue.
  // Negative when the entry is not part of the queue.
  int queueIndex = -1;

  // The service used to send commands to the other isolate.
  Runner runner;

  _LoadBalancerEntry(Runner runner) : runner = runner;

  /// Whether the entry is still in the queue.
  bool get inQueue => queueIndex >= 0;

  Future<R> run<R, P>(
      LoadBalancer balancer,
      int load,
      FutureOr<R> Function(P argument) function,
      argument,
      Duration timeout,
      FutureOr<R> Function() onTimeout) {
    return runner
        .run<R, P>(function, argument, timeout: timeout, onTimeout: onTimeout)
        .whenComplete(() {
      balancer._decreaseLoad(this, load);
    });
  }

  Future close() => runner.close();

  @override
  int compareTo(_LoadBalancerEntry other) => load - other.load;
}
