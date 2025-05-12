import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

mixin SingleTickerProviderRenderObject on RenderObject implements TickerProvider {
  Ticker? _ticker;

  ValueListenable<bool>? _tickerModeNotifier;
  set tickerModeNotifier(ValueListenable<bool> value) {
    if (value == _tickerModeNotifier) {
      return;
    }
    _tickerModeNotifier?.removeListener(_updateTicker);
    value.addListener(_updateTicker);
    _tickerModeNotifier = value;
  }

  @override
  void attach(PipelineOwner owner) {
    _updateTicker();
    super.attach(owner);
  }

  @override
  void dispose() {
    _tickerModeNotifier?.removeListener(_updateTicker);
    _tickerModeNotifier = null;
    super.dispose();
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
    _ticker = Ticker(onTick, debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null);
    _updateTicker();
    return _ticker!;
  }

  void _updateTicker() => _ticker?.muted = !_tickerModeNotifier!.value;
}
