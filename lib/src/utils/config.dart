import 'dart:io';
import 'package:yaml/yaml.dart';
import 'platform_utils.dart';

/// Reads the optional .fia.yaml configuration file.
class Config {
  /// Whether terminal interactive shortcuts are enabled. Defaults to true.
  bool interactive = true;

  /// Asynchronously loads and parses the `.fia.yaml` configuration file.
  static Future<Config> load() async {
    final config = Config();
    final file = File(resolveLocalPath('.fia.yaml'));

    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final yaml = loadYaml(content) as YamlMap?;
        if (yaml != null && yaml.containsKey('interactive')) {
          config.interactive = yaml['interactive'] == true;
        }
      } catch (_) {
        // Silently ignore config parse errors to prevent blocking flutter run
      }
    }
    return config;
  }
}
