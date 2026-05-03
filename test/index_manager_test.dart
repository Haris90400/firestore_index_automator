import 'package:test/test.dart';
import 'package:firestore_index_automator/src/core/index_manager.dart';
import 'package:firestore_index_automator/src/core/proto_parser.dart';
import 'dart:io';

void main() {
  group('Index Manager', () {
    late IndexManager manager;

    setUp(() {
      manager = IndexManager();
      if (File('firestore.indexes.json').existsSync()) {
        File('firestore.indexes.json').deleteSync();
      }
    });

    tearDown(() {
      if (File('firestore.indexes.json').existsSync()) {
        File('firestore.indexes.json').deleteSync();
      }
    });

    test('initializes and ensures file exists', () async {
      await manager.ensureExists();
      final file = File('firestore.indexes.json');
      expect(await file.exists(), isTrue);
    });

    test('adds index and prevents duplicates', () async {
      await manager.ensureExists();
      final config = IndexConfig(
        collectionGroup: 'test_col',
        fields: [IndexField('test_field', FieldOrder.ascending)],
        queryScope: QueryScope.collection,
      );

      final first = await manager.addIndex(config);
      final second = await manager.addIndex(config);

      expect(first, isTrue);
      expect(second, isFalse);
    });
  });
}
