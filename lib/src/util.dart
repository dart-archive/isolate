// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Utility functions.

/// Ignore an argument.
///
/// Can be used to drop the result of a future like `future.then(ignore)`.
void ignore(_) {}

/// Create a single-element fixed-length list.
List<Object> list1(Object v1) => List(1)..[0] = v1;

/// Create a two-element fixed-length list.
List<Object> list2(Object v1, Object v2) => List(2)
  ..[0] = v1
  ..[1] = v2;

/// Create a three-element fixed-length list.
List<Object> list3(Object v1, Object v2, Object v3) => List(3)
  ..[0] = v1
  ..[1] = v2
  ..[2] = v3;

/// Create a four-element fixed-length list.
List<Object> list4(Object v1, Object v2, Object v3, Object v4) => List(4)
  ..[0] = v1
  ..[1] = v2
  ..[2] = v3
  ..[3] = v4;

/// Create a five-element fixed-length list.
List<Object> list5(Object v1, Object v2, Object v3, Object v4, Object v5) =>
    List(5)
      ..[0] = v1
      ..[1] = v2
      ..[2] = v3
      ..[3] = v4
      ..[4] = v5;
