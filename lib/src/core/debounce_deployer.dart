import 'dart:async';
import 'firebase_cli.dart';
import '../utils/logger.dart';

/// Handles debouncing of index deployments to batch them together.
class DebounceDeployer {
  final FirebaseCli _firebaseCli;
  final DateTime _startTime = DateTime.now();
  int _errorsThisSession = 0;
  Timer? _timer;

  /// Callback triggered when deployment starts.
  Function()? onDeployStart;

  /// Callback triggered when deployment finishes.
  Function(bool success)? onDeployComplete;

  /// Callback triggered when the timer ticks.
  Function(int seconds)? onTimerTick;

  /// Creates a new [DebounceDeployer].
  DebounceDeployer(this._firebaseCli);

  /// Calculates the dynamic debounce duration based on app uptime.
  int get debounceSeconds {
    final appUptime = DateTime.now().difference(_startTime);
    if (appUptime.inSeconds < 10) return 20; // startup flood
    if (_errorsThisSession == 1) return 5; // single error
    return 10; // normal session
  }

  /// Triggers a new deployment timer, cancelling any existing one.
  void trigger() {
    _errorsThisSession++;
    cancel();

    final seconds = debounceSeconds;
    if (onTimerTick != null) onTimerTick!(seconds);

    _timer = Timer(Duration(seconds: seconds), deployNow);
  }

  /// Cancels the current deployment timer.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forces an immediate deployment, cancelling any pending timer.
  Future<void> deployNow() async {
    cancel();
    if (onDeployStart != null) onDeployStart!();

    try {
      final success = await _firebaseCli.deployIndexes();
      if (onDeployComplete != null) onDeployComplete!(success);
    } catch (e) {
      Logger.internalError('Deploy failed unexpectedly: $e');
      if (onDeployComplete != null) onDeployComplete!(false);
    }
  }
}
