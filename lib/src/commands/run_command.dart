import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../core/error_detector.dart';
import '../core/process_wrapper.dart';
import '../core/index_manager.dart';
import '../core/debounce_deployer.dart';
import '../core/firebase_cli.dart';
import '../core/proto_parser.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/platform_utils.dart';
import '../utils/hud.dart';
import '../utils/config.dart';

/// The `fia run` command.
/// Wraps `flutter run`, intercepts errors, and deploys missing indexes automatically.
class RunCommand extends Command {
  @override
  final name = 'run';
  @override
  final description = 'Runs flutter app and automates firestore indexes.';

  bool _hudInitialized = false;
  late final ProcessWrapper _processWrapper = ProcessWrapper(
    onFlutterOutput: () {
      if (_hudInitialized) _hud.markFlutterOutput();
    },
  );
  final ErrorDetector _errorDetector = ErrorDetector();
  final IndexManager _indexManager = IndexManager();
  final FirebaseCli _firebaseCli = FirebaseCli();
  late final DebounceDeployer _deployer = DebounceDeployer(_firebaseCli);
  late final Hud _hud;

  int _detectedCount = 0;
  int _deployedCount = 0;
  int _skippedCount = 0;

  final Set<String> _seenConfigHashes = {};
  final List<IndexConfig> _addedIndexes = [];

  String _hashConfig(IndexConfig config) {
    return '${config.collectionGroup}|${config.queryScope.name}|${config.fields.map((f) => '${f.fieldPath}:${f.order.name}').join(',')}';
  }

  /// Creates a new [RunCommand].
  RunCommand() {
    argParser.addFlag(
      'interactive',
      defaultsTo: true,
      help: 'Enable terminal interactive shortcuts',
    );
  }

  @override
  Future<void> run() async {
    final config = await Config.load();
    final isInteractive =
        argResults?['interactive'] == true && config.interactive;

    if (!await _startupChecks()) {
      return;
    }

    _hud = Hud(
      onDeployNow: () {
        _deployer.deployNow();
      },
      onSkip: () {
        _deployer.cancel();
        _hud.clear();
        Logger.info('[FIA] ⏭️ Deploy skipped. JSON was still updated.');
      },
      onView: () {
        _hud.clear();
        Logger.plain('\n--- Pending Indexes ---');
        for (var idx in _addedIndexes) {
          Logger.plain(
            '- ${idx.collectionGroup}: ${idx.fields.map((e) => e.fieldPath).join(", ")}',
          );
        }
        Logger.plain('-----------------------\n');
      },
      onUndo: () {
        _hud.clear();
        Logger.warning(
          '[FIA] ⚠️ Undo not fully implemented. Edit firestore.indexes.json manually.',
        );
      },
      passThrough: (char) {
        _processWrapper.writeStdin(char);
      },
    );
    _hudInitialized = true;

    _deployer.onTimerTick = (seconds) {
      _hud.updatePending(_addedIndexes.length, seconds);
    };

    _deployer.onDeployStart = () {
      _hud.updateDeploying(_addedIndexes.length);
    };

    _deployer.onDeployComplete = (success) {
      if (success) {
        _deployedCount += _addedIndexes.length;
        _addedIndexes.clear();
        _startPolling(immediate: true);
      } else {
        _hud.clear();
      }
    };

    if (isInteractive) {
      _hud.startInteractive();
    }

    ProcessSignal.sigint.watch().listen((_) async {
      await _cleanupAndExit();
    });

    final flutterArgs = argResults?.rest ?? [];

    _processWrapper.stderrStream.listen(_handleLogLine);
    _processWrapper.stdoutStream.listen(_handleLogLine);

    await _processWrapper.start(flutterArgs);
    await _cleanupAndExit();
  }

  void _handleLogLine(String line) async {
    try {
      final url = _errorDetector.processLine(line);
      if (url != null) {
        try {
          final config = parseIndexUrl(url);
          if (config != null) {
            final hash = _hashConfig(config);
            if (_seenConfigHashes.contains(hash)) {
              return; // Silently skip identical index error in this session
            }
            _seenConfigHashes.add(hash);
            _detectedCount++;

            final added = await _indexManager.addIndex(config);

            if (added) {
              _addedIndexes.add(config);
              _deployer.trigger();
            } else {
              _skippedCount++;
              // Silently skip log output to avoid spamming
            }
          } else {
            Logger.warning(parseProtoWarning.replaceAll('{url}', url));
          }
        } catch (e) {
          Logger.warning(parseProtoWarning.replaceAll('{url}', url));
        }
      }
    } catch (e) {
      Logger.internalError('Log handling error: $e');
    }
  }

  Future<void> _startPolling({bool immediate = false}) async {
    int attempts = 0;

    final pollAction = (Timer? timer) async {
      attempts++;
      if (attempts > 60) {
        timer?.cancel();
        _hud.clear();
        Logger.warning(
          '[FIA] ⏰ Index taking longer than expected.\nCheck status: fia status\nOr visit Firebase Console.',
        );
        return;
      }

      final status = await _firebaseCli.getIndexStatus();
      if (status == null) return;

      int building = 0;
      int ready = 0;
      String lastColl = '';

      for (var idx in status) {
        final state = idx['state'];
        if (state == 'CREATING') {
          building++;
          lastColl = idx['collection']?.toString() ?? 'index';
        } else if (state == 'READY') {
          ready++;
        } else if (state == 'NEEDS_REPAIR') {
          timer?.cancel();
          _hud.clear();
          Logger.warning(
            '[FIA] ⚠️ An index needs repair. Check Firebase Console.',
          );
          return;
        }
      }

      if (building > 0) {
        _hud.updateBuilding(lastColl, building);
      } else if (ready > 0 && (attempts > 1 || immediate)) {
        _hud.updateReady(lastColl, ready);
        timer?.cancel();
      }
    };

    if (immediate) {
      await pollAction(null);
    }

    Timer.periodic(const Duration(seconds: 15), (timer) async {
      await pollAction(timer);
    });
  }

  Future<void> _cleanupAndExit() async {
    _hud.stopInteractive();
    _processWrapper.stop();

    Logger.plain('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    Logger.plain('[FIA] Session Summary');
    Logger.plain('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    Logger.plain('Detected  : $_detectedCount indexes');
    Logger.plain('Deployed  : $_deployedCount indexes');
    Logger.plain('Skipped   : $_skippedCount (already existed in JSON)');
    Logger.plain('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (_deployedCount > 0) {
      Logger.plain(
        "[FIA] 💡 Tip: Run 'fia status' anytime to check when remaining indexes are ready.",
      );
    }

    exit(0);
  }

  Future<bool> _startupChecks() async {
    bool passed = true;

    try {
      final nodeResult = await Process.run(executable('node'), ['--version']);
      if (nodeResult.exitCode != 0) throw Exception();
    } catch (_) {
      Logger.error(nodeMissingError);
      passed = false;
    }

    try {
      final flutResult = await Process.run(executable('flutter'), [
        '--version',
      ]);
      if (flutResult.exitCode != 0) throw Exception();
    } catch (_) {
      Logger.error(flutterMissingError);
      passed = false;
    }

    try {
      final fbResult = await Process.run(executable('firebase'), ['--version']);
      if (fbResult.exitCode != 0) throw Exception();

      final versionStr = fbResult.stdout.toString().trim();
      final major = int.tryParse(versionStr.split('.').first) ?? 0;
      if (major < 15) {
        Logger.error(
          firebaseCliMissingError.replaceAll('{version}', versionStr),
        );
        passed = false;
      }
    } catch (_) {
      Logger.error(firebaseCliMissingError.replaceAll('{version}', 'unknown'));
      passed = false;
    }

    final pubspec = File(resolveLocalPath('pubspec.yaml'));
    if (!await pubspec.exists()) {
      Logger.error(noPubspecError);
      passed = false;
    }

    if (!passed) return false;

    final rcFile = File(resolveLocalPath('.firebaserc'));
    if (!await rcFile.exists()) {
      Logger.error(noFirebasercError);
      return false;
    }

    try {
      final projResult = await Process.run(executable('firebase'), [
        'projects:list',
      ]);
      if (projResult.exitCode != 0) {
        Logger.error(notLoggedInError);
        return false;
      }
    } catch (_) {
      Logger.error(notLoggedInError);
      return false;
    }

    await _indexManager.ensureExists();

    return true;
  }
}
