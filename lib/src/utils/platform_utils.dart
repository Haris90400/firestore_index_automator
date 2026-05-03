import 'dart:io';
import 'package:path/path.dart' as p;

/// Returns the platform-specific executable name.
String executable(String name) {
  if (Platform.isWindows) {
    const map = {
      'flutter': 'flutter.bat',
      'firebase': 'firebase.cmd',
      'node': 'node.exe',
      'gcloud': 'gcloud.cmd',
    };
    return map[name] ?? name;
  }
  return name;
}

/// Returns the platform-specific line ending.
String getLineEnding() {
  return Platform.isWindows ? '\r\n' : '\n';
}

/// Returns an absolute path within the current directory.
String resolveLocalPath(String filename) {
  return p.join(Directory.current.path, filename);
}
