import 'package:args/command_runner.dart';
import '../core/firebase_cli.dart';
import '../utils/logger.dart';

/// The `fia status` command.
/// Polls the Firebase REST API to check the build state of indexes.
class StatusCommand extends Command {
  @override
  final name = 'status';
  @override
  final description = 'Polls Firebase REST API to check index states.';

  final FirebaseCli _firebaseCli = FirebaseCli();

  @override
  Future<void> run() async {
    Logger.info('[FIA] Fetching index status...');
    final status = await _firebaseCli.getIndexStatus();

    if (status == null) {
      Logger.error('[FIA] ❌ Failed to fetch index status.');
      return;
    }

    if (status.isEmpty) {
      Logger.info('[FIA] No custom indexes found on this project.');
      return;
    }

    Logger.plain('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    Logger.plain('Firestore Indexes Status');
    Logger.plain('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    for (var idx in status) {
      final state = idx['state'];
      final queryScope = idx['queryScope'];
      final fields = idx['fields'] as List?;

      String fieldNames =
          fields?.map((f) => f['fieldPath']).join(', ') ?? 'unknown';

      String icon = '⏳';
      if (state == 'READY')
        icon = '✅';
      else if (state == 'NEEDS_REPAIR')
        icon = '⚠️';

      Logger.plain('$icon [$state] $queryScope : $fieldNames');
    }
    Logger.plain('━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}
