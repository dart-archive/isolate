// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Convert top-level or static functions to objects that can be sent to
 * other isolates.
 *
 * This package is only needed until such functions can be sent directly
 * through send-ports.
 */
library pkg.isolate.functionref;

import "dart:mirrors";

abstract class FunctionRef {
  static FunctionRef from(Function function) {
    var cm = reflect(function);
    if (cm is ClosureMirror) {
      MethodMirror fm = cm.function;
      if (fm.isRegularMethod && fm.isStatic) {
        Symbol functionName = fm.simpleName;
        Symbol className;
        DeclarationMirror owner = fm.owner;
        if (owner is ClassMirror) {
          className = owner.simpleName;
          owner = owner.owner;
        }
        if (owner is LibraryMirror) {
          LibraryMirror ownerLibrary = owner;
          Uri libraryUri = ownerLibrary.uri;
          return new _FunctionRef(libraryUri, className, functionName);
        }
      }
      throw new ArgumentError.value(function, "function",
                                    "Not a static or top-level function");
    }
    // It's a Function but not a closure, so it's a callable object.
    return new _CallableObjectRef(function);
  }

  Function get function;
}

class _FunctionRef implements FunctionRef {
  final Uri libraryUri;
  final Symbol className;
  final Symbol functionName;

  _FunctionRef(this.libraryUri, this.className, this.functionName);

  Function get function {
    LibraryMirror lm = currentMirrorSystem().libraries[libraryUri];
    if (lm != null) {
      ObjectMirror owner = lm;
      if (className != null) {
        ClassMirror cm = lm.declarations[className];
        owner = cm;
      }
      if (owner != null) {
        ClosureMirror function = owner.getField(this.functionName);
        if (function != null) return function.reflectee;
      }
    }
    String functionName = MirrorSystem.getName(this.functionName);
    String classQualifier = "";
    if (this.className != null) {
      classQualifier  = " in class ${MirrorSystem.getName(this.className)}";
    }
    throw new UnsupportedError(
      "Function $functionName${classQualifier} not found in library $libraryUri"
    );
  }
}

class _CallableObjectRef implements FunctionRef {
  final Function object;
  _CallableObjectRef(this.object);
  Function get function => object;
}
