import 'package:test/test.dart';
import 'package:firestore_index_automator/src/core/proto_parser.dart';

void main() {
  group('Proto Parser', () {
    test('returns null for invalid base64', () {
      expect(
        parseIndexUrl(
          'https://console.firebase.google.com/project/p/firestore/indexes?create_composite=invalid_base64',
        ),
        isNull,
      );
    });

    test('returns null on missing parameter', () {
      expect(
        parseIndexUrl(
          'https://console.firebase.google.com/project/p/firestore/indexes',
        ),
        isNull,
      );
    });
  });
}
