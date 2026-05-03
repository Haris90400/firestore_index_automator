import 'package:test/test.dart';
import 'package:firestore_index_automator/src/core/error_detector.dart';

void main() {
  group('Error Detector', () {
    late ErrorDetector detector;

    setUp(() {
      detector = ErrorDetector();
    });

    test('detects full url on single line', () {
      final line =
          'https://console.firebase.google.com/project/my-app/firestore/indexes?create_composite=Cgdvcm1';
      final result = detector.processLine(line);
      expect(result, isNotNull);
      expect(result, contains('create_composite=Cgdvcm1'));
    });

    test('detects v1/r full url on single line', () {
      final line =
          'https://console.firebase.google.com/v1/r/project/my-app/firestore/indexes?create_composite=Cgdvcm1';
      final result = detector.processLine(line);
      expect(result, isNotNull);
      expect(result, contains('create_composite=Cgdvcm1'));
    });

    test('detects split url across lines', () {
      detector.processLine('https://console.firebase.google.com/v1/r/project/');
      detector.processLine('my-app/firestore/indexes?create_composite=');
      final result = detector.processLine('Cgdvcm1');

      expect(result, isNotNull);
      expect(
        result,
        equals(
          'https://console.firebase.google.com/v1/r/project/my-app/firestore/indexes?create_composite=Cgdvcm1',
        ),
      );
    });

    test('deduplicates identical urls', () {
      final url =
          'https://console.firebase.google.com/project/my-app/firestore/indexes?create_composite=123';
      final first = detector.processLine(url);

      // Send blank lines to flush the rolling buffer so they don't concatenate
      for (int i = 0; i < 5; i++) detector.processLine('');

      final second = detector.processLine(url);

      expect(first, isNotNull);
      expect(second, isNull);
    });
  });
}
