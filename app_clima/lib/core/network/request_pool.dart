import 'dart:async';
import 'dart:collection';

/// Bounds active requests while preserving FIFO order for waiting callers.
class RequestPool {
  RequestPool(this.limit) : assert(limit > 0);

  final int limit;
  int _active = 0;
  final _waiting = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_active >= limit) {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _active++;
    }
    try {
      return await operation();
    } finally {
      if (_waiting.isEmpty) {
        _active--;
      } else {
        _waiting.removeFirst().complete();
      }
    }
  }
}
