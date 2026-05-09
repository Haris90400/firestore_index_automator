import 'dart:async';
import 'dart:io';
import 'logger.dart';
import '../utils/constants.dart';

/// Represents the various visual states of the HUD.
enum HudState {
  /// Hidden or not active.
  idle,

  /// Waiting for more index errors before deploying.
  pending,

  /// Currently running firebase deploy.
  deploying,

  /// Waiting for Google servers to build the index.
  building,

  /// Index is ready to use.
  ready,
}

/// A pinned terminal Heads-Up Display for real-time status.
class Hud {
  HudState _state = HudState.idle;
  int _pendingCount = 0;
  int _deploySeconds = 0;
  int _buildingCount = 0;
  int _readyCount = 0;
  String _lastCollection = '';
  DateTime? _buildStartTime;
  DateTime? _deployStartTime;

  bool _lastLineWasFIA = false;
  HudState _lastState = HudState.idle;

  bool _interactive = true;
  StreamSubscription<List<int>>? _stdinSub;
  Timer? _uiTicker;

  /// Callback for manual deploy override.
  final Function()? onDeployNow;

  /// Callback to skip deploying.
  final Function()? onSkip;

  /// Callback to view the index.
  final Function()? onView;

  /// Callback to undo the last index addition.
  final Function()? onUndo;

  /// Callback to pass characters through to flutter run.
  final Function(String)? passThrough;

  /// Creates a new [Hud].
  Hud({
    this.onDeployNow,
    this.onSkip,
    this.onView,
    this.onUndo,
    this.passThrough,
  });

  /// Starts listening to stdin for keyboard shortcuts without echoing them.
  void startInteractive() {
    if (!stdin.hasTerminal) {
      _interactive = false;
      return;
    }

    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
      _interactive = true;

      _stdinSub = stdin.listen((bytes) {
        final char = String.fromCharCodes(bytes);
        final lower = char.toLowerCase();

        if (lower == 'd') {
          onDeployNow?.call();
        } else if (lower == 's') {
          onSkip?.call();
        } else if (lower == 'v') {
          onView?.call();
        } else if (lower == 'u') {
          onUndo?.call();
        } else {
          // Pass through to flutter run (like 'r' or 'R')
          passThrough?.call(char);
        }
      });
    } catch (e) {
      _interactive = false;
      Logger.plain(keyboardShortcutsUnavailable);
    }
  }

  /// Restores normal terminal stdin behavior.
  void stopInteractive() {
    if (_interactive && stdin.hasTerminal) {
      try {
        stdin.echoMode = true;
        stdin.lineMode = true;
      } catch (_) {}
    }
    _stdinSub?.cancel();
    _stopUiTicker();
  }

  /// Updates HUD to show pending index deployments.
  void updatePending(int count, int seconds) {
    _state = HudState.pending;
    _pendingCount = count;
    _deploySeconds = seconds;
    _startUiTicker();
    _render();
  }

  /// Updates HUD to show active deployment status.
  void updateDeploying(int count) {
    _state = HudState.deploying;
    _pendingCount = count;
    _deployStartTime = DateTime.now();
    _startUiTicker();
    _render();
  }

  /// Updates HUD to show indexes currently building on Google servers.
  void updateBuilding(String collection, int count) {
    if (_state != HudState.building) {
      _buildStartTime = DateTime.now();
    }
    _state = HudState.building;
    _lastCollection = collection;
    _buildingCount = count;
    _startUiTicker();
    _render();
  }

  /// Updates HUD to show that indexes are ready.
  void updateReady(String collection, int count) {
    _state = HudState.ready;
    _lastCollection = collection;
    _readyCount = count;
    _stopUiTicker();
    _render();
  }

  /// Tells the HUD that a standard log line was printed, preventing overwriting.
  void markFlutterOutput() {
    _lastLineWasFIA = false;
  }

  /// Clears the HUD from the terminal (unused in current ANSI mode).
  void clear() {
    // Replaced by _lastLineWasFIA approach
  }

  /// Manually forces the HUD to render its current state.
  void render() {
    _render();
  }

  void _startUiTicker() {
    if (_uiTicker != null && _uiTicker!.isActive) return;
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _render();
    });
  }

  void _stopUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = null;
  }

  void _render() {
    String line = '';

    switch (_state) {
      case HudState.idle:
        return;
      case HudState.pending:
        final shortcuts = _interactive ? ' | D:now S:skip V:view U:undo' : '';
        line =
            '[FIA] 📦 $_pendingCount indexes pending | deploying in ${_deploySeconds}s$shortcuts';
        if (Logger.supportsAnsi) line = '\x1B[33m$line\x1B[0m';
        break;
      case HudState.deploying:
        final elapsed = _deployStartTime != null
            ? DateTime.now().difference(_deployStartTime!).inSeconds
            : 0;
        line =
            '[FIA] 🚀 Deploying $_pendingCount indexes... (firebase CLI running ${elapsed}s)';
        if (Logger.supportsAnsi) line = '\x1B[36m$line\x1B[0m';
        break;
      case HudState.building:
        final elapsed = _buildStartTime != null
            ? DateTime.now().difference(_buildStartTime!).inSeconds
            : 0;
        final minutes = elapsed ~/ 60;
        final seconds = elapsed % 60;
        final timeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

        line =
            '[FIA] 🏗  $_lastCollection $_buildingCount building ($timeStr)...';
        if (Logger.supportsAnsi) line = '\x1B[33m$line\x1B[0m';
        break;
      case HudState.ready:
        line =
            '[FIA] ✅ $_lastCollection $_readyCount → READY! Press r to hot reload';
        if (Logger.supportsAnsi) line = '\x1B[32m$line\x1B[0m';
        break;
    }

    // Pad with spaces to clear old characters on Windows (to avoid ghosting)
    if (Platform.isWindows && line.length < 80) {
      line = line.padRight(80);
    }

    if (stdout.supportsAnsiEscapes) {
      if (_lastLineWasFIA) {
        // Move cursor up and clear line
        stdout.write('\x1B[1A\x1B[2K');
      }
      stdout.write('$line\n');
      _lastLineWasFIA = true;
      _lastState = _state;
    } else if (Platform.isWindows) {
      // Fallback for Windows without ANSI support (use carriage return)
      // Only use \r if the last line was FIA to avoid overwriting flutter logs
      if (_lastLineWasFIA) {
        stdout.write('\r$line');
      } else {
        stdout.writeln('\n$line');
      }
      _lastLineWasFIA = true;
      _lastState = _state;
    } else {
      // Total fallback
      if (_state != _lastState || !_lastLineWasFIA) {
        stdout.writeln(line);
        _lastLineWasFIA = true;
        _lastState = _state;
      }
    }
  }
}
