import 'dart:async';
import 'dart:io';
import '../utils/platform_utils.dart';
import '../utils/logger.dart';

/// Wraps the flutter run subprocess and pipes its output.
class ProcessWrapper {
  /// Callback triggered whenever the flutter process outputs to stdout or stderr.
  final void Function()? onFlutterOutput;

  /// Creates a new [ProcessWrapper].
  ProcessWrapper({this.onFlutterOutput});

  Process? _process;
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> _stderrController =
      StreamController<String>.broadcast();

  /// Stream of stdout text from the flutter process.
  Stream<String> get stdoutStream => _stdoutController.stream;

  /// Stream of stderr text from the flutter process.
  Stream<String> get stderrStream => _stderrController.stream;

  /// Starts `flutter run` with the provided arguments.
  Future<int> start(List<String> flutterArgs) async {
    try {
      _process = await Process.start(executable('flutter'), [
        'run',
        ...flutterArgs,
      ], runInShell: true);

      _process!.stdout.listen((bytes) {
        final text = String.fromCharCodes(bytes);
        stdout.write(text); // Pass through normally
        _stdoutController.add(text);
        onFlutterOutput?.call();
      });

      _process!.stderr.listen((bytes) {
        final text = String.fromCharCodes(bytes);
        stderr.write(text);
        _stderrController.add(text);
        onFlutterOutput?.call();
      });

      return await _process!.exitCode;
    } catch (e) {
      Logger.internalError('ProcessWrapper failed to start flutter: $e');
      return 1;
    } finally {
      await _stdoutController.close();
      await _stderrController.close();
    }
  }

  /// Stops the running process.
  void stop() {
    _process?.kill();
  }

  /// Write to the flutter process stdin
  void writeStdin(String input) {
    _process?.stdin.write(input);
  }
}
