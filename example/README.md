# FIA Example Usage

This directory provides an example of how to use the `fia` tool in a real-world Flutter and Firebase project.

## 1. Installation

First, install the tool globally:

```bash
dart pub global activate firestore_index_automator
```

Ensure your system's PATH includes the global pub executable directory so you can run `fia` from anywhere.

## 2. Project Setup

Navigate to your existing Flutter project that uses `cloud_firestore`. Make sure Firebase is initialized.

```bash
cd my_flutter_project
firebase init firestore
```

## 3. Running Your App

Instead of running your app with the standard `flutter run` command, simply prefix it with `fia`. You can pass any arguments you normally would:

```bash
fia run -d chrome
```

### What Happens Next?

1. Your app starts exactly as it normally would.
2. You navigate through your app to a screen that triggers a complex Firestore query (e.g., filtering by `category` and sorting by `price`).
3. Firestore throws a `FAILED_PRECONDITION` error because the composite index doesn't exist yet.

### The Terminal Experience

Normally, you would see the error and have to manually click the URL. With `fia run`, the tool intercepts the error and pins a live status bar (HUD) to the bottom of your terminal:

```text
I/flutter: [cloud_firestore/failed-precondition] The query requires an index...
[FIA] 📦 1 indexes pending | deploying in 8s | D:now S:skip V:view U:undo
```

Once the countdown finishes, FIA automatically triggers the Firebase CLI in the background:

```text
[FIA] 🚀 Deploying 1 indexes... (firebase CLI running)
```

## 4. Checking Status

If you want to see if your indexes have finished building on Google's servers, you don't need to open the Firebase Console. Just open a new terminal tab and run:

```bash
fia status
```

You will see output like this:

```text
[FIA] ⏳ 1 index(es) still building...
[FIA] ✅ All indexes are ready!
```

## 5. Advanced Configuration

You can customize FIA's behavior by creating a `.fia.yaml` file in the root of your project:

```yaml
# .fia.yaml
auto_deploy: true       # Automatically trigger firebase deploy
debounce_seconds: 15    # Wait 15 seconds for more errors before deploying
interactive: true       # Allow D, S, V, U keyboard shortcuts in the terminal
```
