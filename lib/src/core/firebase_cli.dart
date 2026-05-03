import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/platform_utils.dart';
import '../utils/logger.dart';

/// Bridge to firebase-tools CLI and Firestore REST API.
class FirebaseCli {
  String? _cachedProjectId;
  String? _cachedToken;
  bool _pollingDisabled = false;

  /// Retrieves the default project ID from `.firebaserc`.
  Future<String?> getProjectId() async {
    if (_cachedProjectId != null) return _cachedProjectId;

    final rcFile = File(resolveLocalPath('.firebaserc'));
    if (!await rcFile.exists()) return null;

    try {
      final content = await rcFile.readAsString();
      final decoded = jsonDecode(content);
      _cachedProjectId = decoded['projects']?['default'];
      return _cachedProjectId;
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the authentication token for Firestore REST API access.
  /// Falls back to `gcloud auth print-access-token` if `firebase auth:token` fails.
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    if (_pollingDisabled) return null;

    // Try firebase auth:token
    try {
      final result = await Process.run(executable('firebase'), [
        'auth:token',
        '--non-interactive',
      ]);
      if (result.exitCode == 0) {
        _cachedToken = result.stdout.toString().trim();
        return _cachedToken;
      }
    } catch (_) {}

    // Fallback: gcloud auth print-access-token
    try {
      final result = await Process.run(executable('gcloud'), [
        'auth',
        'print-access-token',
      ]);
      if (result.exitCode == 0) {
        _cachedToken = result.stdout.toString().trim();
        return _cachedToken;
      }
    } catch (_) {}

    // Both failed
    _pollingDisabled = true;
    Logger.plain(
      '[FIA] ℹ️ Index polling unavailable. \n'
      '         Indexes are deploying in background.\n'
      '         Check status: Firebase Console → Firestore → Indexes tab\n'
      '         Or run: fia status',
    );
    return null;
  }

  /// Deploys the current `firestore.indexes.json` using the Firebase CLI.
  Future<bool> deployIndexes() async {
    final projectId = await getProjectId();
    if (projectId == null) {
      Logger.error('[FIA] ❌ Cannot deploy: no project ID found in .firebaserc');
      return false;
    }

    try {
      final result = await Process.run(executable('firebase'), [
        'deploy',
        '--only',
        'firestore:indexes',
        '--project',
        projectId,
        '--non-interactive',
      ]);

      if (result.exitCode == 0) return true;

      final stderrText = result.stderr.toString();
      final stdoutText = result.stdout.toString();
      final combinedError = '$stderrText\n$stdoutText'.trim();

      if (combinedError.contains('requires authentication') ||
          combinedError.contains('not logged in')) {
        Logger.error(
          '[FIA] ❌ Deploy failed: Not logged in. Run "firebase login".',
        );
      } else if (combinedError.contains('Unknown project') ||
          combinedError.contains('does not exist')) {
        Logger.error('[FIA] ❌ Deploy failed: Invalid project ID.');
      } else {
        Logger.error(
          '[FIA] ❌ Deploy failed:\n$combinedError\n\nHint: Try manual deploy: firebase deploy --only firestore:indexes',
        );
      }
      return false;
    } catch (e) {
      Logger.error('[FIA] ❌ Unexpected deploy error: $e');
      return false;
    }
  }

  /// Fetches the status of all indexes from the Firestore REST API.
  Future<List<Map<String, dynamic>>?> getIndexStatus() async {
    final projectId = await getProjectId();
    final token = await getToken();

    if (projectId == null || token == null) return null;

    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/collectionGroups/-/indexes',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final indexes = decoded['indexes'] as List?;
        return indexes?.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      Logger.internalError('Polling failed: $e');
    }
    return null;
  }
}
