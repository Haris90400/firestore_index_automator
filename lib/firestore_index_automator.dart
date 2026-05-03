/// FIA (Firestore Index Automator) — A Dart CLI
/// tool that wraps [flutter run] and automatically
/// detects, parses, and deploys missing Firestore
/// composite indexes from your debug terminal.
///
/// No more manually clicking index creation links
/// in the Firebase Console.
///
/// ## Installation
/// ```sh
/// dart pub global activate firestore_index_automator
/// ```
///
/// ## Usage
/// ```sh
/// # Run your Flutter app with auto index detection
/// fia run
///
/// # Check index build status
/// fia status
///
/// # Manually trigger deploy
/// fia deploy
///
/// # Export current indexes from Firebase
/// fia export
/// ```
///
/// ## Configuration
/// Create a `.fia.yaml` in your project root:
/// ```yaml
/// auto_deploy: true
/// debounce_seconds: 10
/// ```
library firestore_index_automator;
