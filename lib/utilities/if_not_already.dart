import 'dart:async';

class IfNotAlready {
  final void Function() _function;

  bool _locked = false;

  IfNotAlready(this._function);

  void execute() {
    if (_locked) return;
    _locked = true;
    try {
      _function();
    } finally {
      _locked = false;
    }
  }
}

class IfNotAlreadyAsync {
  final Future<void> Function() _function;

  bool _locked = false;

  IfNotAlreadyAsync(this._function);

  Future<void> execute() async {
    if (!_locked) {
      _locked = true;
      try {
        await _function();
      } finally {
        _locked = false;
      }
    }
  }
}
