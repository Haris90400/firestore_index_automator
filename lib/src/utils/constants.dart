/// String constants and error messages used throughout FIA.
library constants;

const String fiaPrefix = '[FIA]';

const String nodeMissingError =
    '''
$fiaPrefix ❌ Node.js not found.
      Firebase CLI requires Node.js to run.
      Install LTS version from: https://nodejs.org
      Then run: npm install -g firebase-tools
''';

const String flutterMissingError =
    '''
$fiaPrefix ❌ Flutter SDK not found in PATH.
      Install from: https://flutter.dev/docs/get-started/install
''';

const String firebaseCliMissingError =
    '''
$fiaPrefix ❌ Firebase CLI not found or version too old.
      Required: >= 15.0.0 | Found: {version}
      Update with: npm install -g firebase-tools
''';

const String notLoggedInError =
    '''
$fiaPrefix ❌ Not logged into Firebase.
      Run: firebase login
      Then retry: fia run
''';

const String noFirebasercError =
    '''
$fiaPrefix ❌ .firebaserc not found in current directory.
      Make sure you're in your Flutter project root.
      Or run: firebase init
''';

const String noPubspecError =
    '''
$fiaPrefix ❌ No pubspec.yaml found.
      Run fia from your Flutter project root directory.
''';

const String createdJsonMessage =
    '$fiaPrefix 📝 Created firestore.indexes.json';

const String parseProtoWarning =
    '$fiaPrefix ⚠️ Could not parse index URL.\n          Open manually: {url}';

const String keyboardShortcutsUnavailable =
    '''
$fiaPrefix Keyboard shortcuts unavailable in this terminal.
            Use --no-interactive flag next time.
''';

const String internalErrorPrefix = '[$fiaPrefix Internal Error]';

final RegExp indexUrlRegex = RegExp(
  r'https://console\.firebase\.google\.com/project/([^/\s]+)/firestore/indexes\?create_composite=([\w+/=_-]+)',
  caseSensitive: false,
  multiLine: true,
);
