import 'package:args/command_runner.dart';
import '../core/firebase_cli.dart';
import '../utils/logger.dart';

/// The `fia deploy` command.
/// Manually triggers a deployment of `firestore.indexes.json`.
class DeployCommand extends Command {
  @override
  final name = 'deploy';
  @override
  final description =
      'Manually triggers firebase deploy for firestore indexes.';

  final FirebaseCli _firebaseCli = FirebaseCli();

  @override
  Future<void> run() async {
    Logger.info('[FIA] 🚀 Manually deploying indexes...');
    final success = await _firebaseCli.deployIndexes();
    if (success) {
      Logger.info('[FIA] ✅ Deploy successful.');
    } else {
      Logger.error('[FIA] ❌ Deploy failed.');
    }
  }
}
