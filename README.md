# FIA (Firestore Index Automator)

[![pub package](https://img.shields.io/pub/v/firestore_index_automator.svg)](https://pub.dev/packages/firestore_index_automator)
[![Likes](https://img.shields.io/pub/likes/firestore_index_automator)](https://pub.dev/packages/firestore_index_automator)
[![Popularity](https://img.shields.io/pub/popularity/firestore_index_automator)](https://pub.dev/packages/firestore_index_automator/score)
[![Pub Points](https://img.shields.io/pub/points/firestore_index_automator)](https://pub.dev/packages/firestore_index_automator/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

### What is FIA?
FIA (Firestore Index Automator) is a CLI tool that wraps `flutter run`. It automatically detects missing Firestore composite indexes from your debug terminal, parses the required fields, and seamlessly deploys them to your Firebase project in the background—completely eliminating the need to manually click links and build indexes in the Firebase Console.

---

### The Problem
Every Flutter + Firebase developer knows the pain: you write a slightly complex Firestore query, run your app, and immediately hit a `FAILED_PRECONDITION` error. 

```
The query requires an index. You can create it here: https://console.firebase.google.com/...
```

You have to scroll up in your terminal, Ctrl+Click the link, wait for the Firebase Console to load, click "Create Index", wait 5 minutes, and then restart your app. If you have 10 complex queries, you have to do this 10 times. It completely breaks your development flow.

---

### Installation

Install the package globally via dart pub:

```bash
dart pub global activate firestore_index_automator
```

Make sure your system's PATH is configured to run global Dart executables.

---

### Prerequisites

FIA acts as a bridge between Flutter and the Firebase CLI. Ensure you have the following installed and configured:

1. **Flutter SDK** (`>=3.10.0`)
2. **Node.js** (Required for Firebase CLI)
3. **Firebase CLI** (`firebase-tools >=13.0.0`)
   - You must be logged in: `firebase login`

---

### Quick Start

Using FIA is completely frictionless. It works as a drop-in replacement for `flutter run`.

1. Navigate to the root of your existing Flutter project.
2. Ensure you have initialized Firebase (`firebase init firestore` / `.firebaserc` exists).
3. Start your app using `fia run` instead of `flutter run`:
   ```bash
   fia run
   ```
4. Use your app normally. Whenever a missing index error occurs, FIA intercepts it.
5. FIA will automatically create `firestore.indexes.json` and deploy the index in the background using the Firebase CLI. Your terminal will display a live, pinned HUD with the deployment status!

*(Note: You can pass any standard flutter arguments through FIA: `fia run -d chrome`)*

---

### Commands Reference

| Command | Description |
|---|---|
| `fia run [args]` | Starts your app, intercepts `flutter run` logs, and auto-deploys missing indexes. |
| `fia status` | Polls the Firestore REST API to show you the real-time build progress of pending indexes. |
| `fia deploy` | Manually triggers a deployment of the current `firestore.indexes.json` file. |
| `fia export` | Pulls your existing indexes from the Firebase Console and saves them to your local JSON file. |

---

### How It Works

1. **Detection**: FIA pipes the standard output of `flutter run`. It uses an intelligent rolling buffer and regex engine to detect `FAILED_PRECONDITION` index URLs, even if the terminal window wraps the text across multiple lines.
2. **Parsing**: The tool extracts the `create_composite` Base64 payload from the URL and reverse-engineers the Protobuf structure (supporting both legacy API formats and the modern `v1/r` naming schemas) to extract the exact `collectionGroup`, `queryScope`, and ordered `fields`.
3. **Storage**: The parsed index is safely merged into your local `firestore.indexes.json` file, ensuring no duplicates are created.
4. **Deployment**: FIA uses a smart "debounce" mechanism. It waits 10 seconds for any subsequent index errors (preventing spam deployments), and then automatically fires a headless `firebase deploy --only firestore:indexes` command in the background.

---

### Configuration

You can customize FIA's behavior by creating a `.fia.yaml` file in the root of your project.

```yaml
# .fia.yaml
auto_deploy: true       # Set to false if you just want to update the JSON without deploying.
debounce_seconds: 10    # How long to wait for more errors before deploying a batch.
interactive: true       # Enables terminal keyboard shortcuts (D to deploy now, S to skip, etc.)
```

---

### Platform Support

FIA is heavily tested and relies entirely on standard Dart asynchronous streams and cross-platform Process APIs.
- Windows ✅ (CMD, PowerShell, Git Bash)
- macOS ✅ (Terminal, iTerm2)
- Linux ✅

---

### Contributing

Contributions are very welcome! If you find a bug (like a new Firebase log format that isn't being detected), please open an issue or submit a pull request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

### License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/Haris90400/fia/blob/main/LICENSE) file for details.
