import 'dart:convert';
import 'dart:io';
import 'proto_parser.dart';
import '../utils/platform_utils.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';

/// Manages reading, writing, and deduplicating firestore.indexes.json.
class IndexManager {
  bool _isWriting = false;
  final List<IndexConfig> _pendingQueue = [];

  File get _file => File(resolveLocalPath('firestore.indexes.json'));

  /// Ensures the file exists, creating it if necessary.
  Future<void> ensureExists() async {
    if (!await _file.exists()) {
      await _file.writeAsString(
        '{\n  "indexes": [],\n  "fieldOverrides": []\n}${getLineEnding()}',
      );
      Logger.info(createdJsonMessage);
    }
  }

  /// Reads the current indexes from the JSON file.
  Future<List<Map<String, dynamic>>> readIndexes() async {
    await ensureExists();
    try {
      final content = await _file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final indexes = decoded['indexes'] as List?;
      return indexes?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      Logger.internalError('Failed to read index file: $e');
      return [];
    }
  }

  /// Attempts to add a new index to the JSON file.
  /// Deduplicates automatically.
  Future<bool> addIndex(IndexConfig config) async {
    if (_isWriting) {
      _pendingQueue.add(config);
      return false; // Queued
    }

    _isWriting = true;
    bool added = false;

    try {
      final content = await _file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;

      final indexes =
          (decoded['indexes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (!_isDuplicate(indexes, config)) {
        indexes.add(config.toJson());
        decoded['indexes'] = indexes;

        final encoder = JsonEncoder.withIndent('  ');
        final jsonString = encoder.convert(decoded);

        // Ensure platform line endings
        final finalString = jsonString
            .replaceAll('\r\n', '\n')
            .replaceAll('\n', getLineEnding());

        await _file.writeAsString(finalString);
        added = true;
      }
    } catch (e) {
      Logger.internalError('Failed to write JSON: $e');
    } finally {
      _isWriting = false;
      if (_pendingQueue.isNotEmpty) {
        final next = _pendingQueue.removeAt(0);
        await addIndex(next); // Process queue
      }
    }

    return added;
  }

  bool _isDuplicate(List<Map<String, dynamic>> existing, IndexConfig config) {
    for (final index in existing) {
      if (index['collectionGroup'] == config.collectionGroup) {
        final fields = index['fields'] as List?;
        if (fields != null && fields.length == config.fields.length) {
          bool allMatch = true;
          for (int i = 0; i < fields.length; i++) {
            final f1 = fields[i];
            final f2 = config.fields[i].toJson();
            if (f1['fieldPath'] != f2['fieldPath'] ||
                f1['order'] != f2['order']) {
              allMatch = false;
              break;
            }
          }
          if (allMatch) return true;
        }
      }
    }
    return false;
  }
}
