import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
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
  Future<String?> getToken({bool force = false}) async {
    if (_cachedToken != null && !force) return _cachedToken;
    if (_pollingDisabled && !force) return null;

    // Try firebase auth:token
    try {
      final result = await Process.run(executable('firebase'), [
        'auth:token',
        '--non-interactive',
      ]);
      if (result.exitCode == 0) {
        final token = result.stdout.toString().trim();
        if (token.isNotEmpty) {
          _cachedToken = token;
          return _cachedToken;
        }
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

    // Fallback 2: Read from local config file (last resort)
    try {
      final token = await _getTokenFromConfig(force: force);
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        return _cachedToken;
      }
    } catch (_) {}

    // Both failed
    _pollingDisabled = true;
    Logger.plain(
      '[FIA] ℹ️ Index polling unavailable (Auth failed). \n'
      '         Please ensure you are logged in:\n'
      '         1. Run: firebase login\n'
      '         2. Or Run: gcloud auth application-default login\n'
      '         Check progress manually: Firebase Console → Firestore → Indexes tab',
    );
    return null;
  }

  /// Attempts to read the access token directly from the firebase-tools config file.
  Future<String?> _getTokenFromConfig({bool force = false}) async {
    try {
      String? home = Platform.isWindows
          ? Platform.environment['USERPROFILE']
          : Platform.environment['HOME'];
      if (home == null) return null;

      final configPath = p.join(
        home,
        '.config',
        'configstore',
        'firebase-tools.json',
      );
      final configFile = File(configPath);

      if (!await configFile.exists()) {
        Logger.error('[FIA] ❌ Config file not found at: $configPath');
        return null;
      }

      final content = await configFile.readAsString();
      final decoded = jsonDecode(content);

      // Check if current token is expired
      final expiresAt =
          decoded['tokens']?['expires_at'] ??
          decoded['user']?['tokens']?['expires_at'];
      final refreshToken =
          decoded['tokens']?['refresh_token'] ??
          decoded['user']?['tokens']?['refresh_token'];

      if (refreshToken != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final isExpired = expiresAt != null && now >= (expiresAt as int);

        if (isExpired || force) {
          final newToken = await _refreshToken(refreshToken.toString());
          if (newToken != null) {
            return newToken;
          }
        }
      }

      // Try different common paths in the JSON
      String? token =
          decoded['tokens']?['access_token']?.toString() ??
          decoded['user']?['tokens']?['access_token']?.toString();

      if (token == null && decoded is Map) {
        token = _findKey(decoded, 'access_token');
      }

      return token;
    } catch (e) {
      return null;
    }
  }

  /// Parses the collection group name from the full index resource name.
  /// Format: projects/{p}/databases/{d}/collectionGroups/{collectionGroup}/indexes/{i}
  String _parseCollection(Map<String, dynamic> idx) {
    final name = idx['name']?.toString() ?? '';

    // 1. Try explicit collectionGroup field
    if (idx.containsKey('collectionGroup')) {
      return idx['collectionGroup'].toString();
    }

    // 2. Parse from 'name' resource path
    final parts = name.split('/');
    for (int i = 0; i < parts.length - 1; i++) {
      if (parts[i] == 'collectionGroups') {
        return parts[i + 1];
      }
    }

    // 3. Fallback to queryScope or 'index'
    return idx['queryScope']?.toString() ?? 'index';
  }

  /// Refreshes the access token by triggering a Firebase CLI command.
  Future<String?> _refreshToken(String refreshToken) async {
    try {
      // Running projects:list forces the CLI to refresh the token in the config file
      await Process.run(executable('firebase'), ['projects:list']);

      // Re-read the file to get the new token
      final home =
          Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Platform.environment['HOMEPATH'] ??
          '.';

      final configPath = p.join(
        home,
        '.config',
        'configstore',
        'firebase-tools.json',
      );
      final configFile = File(configPath);
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final decoded = jsonDecode(content);
        return decoded['tokens']?['access_token']?.toString() ??
            decoded['user']?['tokens']?['access_token']?.toString();
      }
    } catch (_) {}
    return null;
  }

  String? _findKey(Map map, String key) {
    if (map.containsKey(key)) return map[key]?.toString();
    for (var value in map.values) {
      if (value is Map) {
        final found = _findKey(value, key);
        if (found != null) return found;
      }
    }
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

      // If the index already exists (HTTP 409), treat it as success
      if (combinedError.contains('HTTP Error: 409') ||
          combinedError.contains('index already exists')) {
        return true;
      }

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

    if (token == null) {
      return null;
    }

    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/collectionGroups/-/indexes',
    );

    try {
      var response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      // If unauthorized, try to refresh once
      if (response.statusCode == 401) {
        _cachedToken = null;
        final newToken = await getToken(force: true);
        if (newToken != null) {
          response = await http.get(
            url,
            headers: {'Authorization': 'Bearer $newToken'},
          );
        }
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final indexes = decoded['indexes'] as List?;
        if (indexes == null) return [];

        return indexes.map((idx) {
          final map = Map<String, dynamic>.from(idx as Map);
          map['collection'] = _parseCollection(map);
          return map;
        }).toList();
      } else {
        Logger.error(
          '[FIA] API Error (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      Logger.internalError('Polling failed: $e');
    }
    return null;
  }
}
