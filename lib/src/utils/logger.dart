import 'dart:io';
import 'package:ansi_styles/ansi_styles.dart';

/// Handles ANSI and plain text console output.
class Logger {
  /// Indicates whether the terminal supports ANSI color escape sequences.
  static final bool supportsAnsi = stdout.supportsAnsiEscapes;

  /// Prints an informational message (green).
  static void info(String message) {
    if (supportsAnsi) {
      stdout.writeln(AnsiStyles.green(message));
    } else {
      stdout.writeln(message);
    }
  }

  /// Prints a warning message (yellow).
  static void warning(String message) {
    if (supportsAnsi) {
      stdout.writeln(AnsiStyles.yellow(message));
    } else {
      stdout.writeln(message);
    }
  }

  /// Prints an error message (red) to stderr.
  static void error(String message) {
    if (supportsAnsi) {
      stderr.writeln(AnsiStyles.red(message));
    } else {
      stderr.writeln(message);
    }
  }

  /// Prints a plain message without formatting.
  static void plain(String message) {
    stdout.writeln(message);
  }

  /// Prints an internal error message (red) for developer debugging.
  static void internalError(String errorMsg) {
    stderr.writeln('[FIA Internal Error] $errorMsg — continuing');
  }
}
