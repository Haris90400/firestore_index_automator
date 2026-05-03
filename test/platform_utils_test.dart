import 'package:test/test.dart';
import 'package:firestore_index_automator/src/utils/platform_utils.dart';
import 'dart:io';

void main() {
  group('Platform Utils', () {
    test('resolves executable based on platform', () {
      final exec = executable('flutter');
      if (Platform.isWindows) {
        expect(exec, equals('flutter.bat'));
      } else {
        expect(exec, equals('flutter'));
      }
    });

    test('returns correct line ending', () {
      final ending = getLineEnding();
      if (Platform.isWindows) {
        expect(ending, equals('\r\n'));
      } else {
        expect(ending, equals('\n'));
      }
    });
  });
}
