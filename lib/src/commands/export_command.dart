import 'package:args/command_runner.dart';
import '../core/firebase_cli.dart';
import '../utils/logger.dart';

/// The `fia export` command.
/// Fetches current indexes from Firebase and syncs them to `firestore.indexes.json`.
class ExportCommand extends Command {
  @override
  final name = 'export';
  @override
  final description =
      'Fetches current indexes from Firebase and writes to local JSON.';

  final FirebaseCli _firebaseCli = FirebaseCli();

  @override
  Future<void> run() async {
    Logger.info('[FIA] 📥 Exporting indexes from Firebase...');
    final status = await _firebaseCli.getIndexStatus();

    if (status == null) {
      Logger.error('[FIA] ❌ Failed to fetch indexes.');
      return;
    }

    Logger.warning(
      '[FIA] ⚠️ Export command partially implemented. Needs JSON mapping.',
    );
  }
}
