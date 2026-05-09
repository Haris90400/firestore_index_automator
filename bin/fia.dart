import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:firestore_index_automator/src/commands/run_command.dart';
import 'package:firestore_index_automator/src/commands/status_command.dart';
import 'package:firestore_index_automator/src/commands/deploy_command.dart';
import 'package:firestore_index_automator/src/commands/export_command.dart';
import 'package:firestore_index_automator/src/utils/logger.dart';

/// Entrypoint for the `fia` CLI executable.
void main(List<String> arguments) async {
  final runner = CommandRunner('fia', 'Firestore Index Automator')
    ..addCommand(RunCommand())
    ..addCommand(StatusCommand())
    ..addCommand(DeployCommand())
    ..addCommand(ExportCommand());

  runner.argParser.addFlag(
    'version',
    negatable: false,
    help: 'Print the tool version.',
  );

  try {
    List<String> modifiedArgs = List.from(arguments);
    if (modifiedArgs.isNotEmpty && modifiedArgs.first == 'run') {
      int insertIndex = 1;
      while (insertIndex < modifiedArgs.length) {
        if (modifiedArgs[insertIndex] == '--interactive' ||
            modifiedArgs[insertIndex] == '--no-interactive') {
          insertIndex++;
        } else {
          break;
        }
      }
      // Inject '--' so the argParser ignores flutter run flags
      modifiedArgs.insert(insertIndex, '--');
    }

    final parsed = runner.argParser.parse(modifiedArgs);
    if (parsed['version'] == true) {
      Logger.plain('fia version: 0.1.4');
      return;
    }

    await runner.run(modifiedArgs);
  } catch (e) {
    Logger.error('Error: $e');
    exit(1);
  }
}
