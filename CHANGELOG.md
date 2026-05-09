# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4] - 2026-05-08

### Added
- Implemented automatic OAuth2 token refresh (no more manual auth tokens needed).
- Added real-time building timer to the HUD with smooth ticking.
- Added collection group name parsing in `fia status` and HUD.

### Fixed
- Improved terminal stability on Windows by disabling line clearing in HUD.
- Handled HTTP 409 'index already exists' error gracefully.
- Fixed authentication failures for users with newer Firebase CLI versions.

## [0.1.3] - 2026-05-03

### Fixed
- Removed ansi_styles dependency causing pub.dev analysis failures
- Replaced with native ANSI escape codes

## [0.1.2] - 2026-05-03

### Fixed
- Fixed encoding issue in package description

## [0.1.1] - 2026-05-03

### Fixed
- Fixed repository, homepage, and issue_tracker URLs in pubspec.yaml
- Removed pubspec.lock from published package to fix pub.dev dependency analysis
- Added explicit platform support declarations (linux, macos, windows)
- Added main library file for pub.dev documentation score

## [0.1.0] - 2026-05-03

### Added
- **Package Name**: Published under `firestore_index_automator` (executable remains `fia`).
- **Error Detection**: Implemented intelligent rolling buffer and regex engine to detect and extract fragmented Firestore `FAILED_PRECONDITION` index URLs from live terminal output.
- **Protobuf Parsing**: Built a base64 decoder and Protobuf parser that supports both legacy API and modern `v1/r` naming schemas to extract `collectionGroup`, `queryScope`, and index `fields`.
- **Auto Deploy**: Integrated `firebase-tools` CLI to automatically deploy parsed indexes in the background.
- **Smart Debounce**: Implemented a deployment debouncer that batches multiple detected indexes together to prevent hitting Firebase deployment rate limits.
- **Live HUD**: Added a robust, pinned, ANSI-styled terminal Heads-Up Display (HUD) that shows real-time pending indexes, deployment status, and building progress without getting buried in flutter logs.
- **Keyboard Shortcuts**: Added interactive terminal controls (e.g., `d` to force deploy, `s` to skip) while piping other commands back to the underlying `flutter run` process.
- **Session Summary**: Added a clean summary printout upon exit detailing exactly how many indexes were detected, deployed, and skipped.
- **Startup Checks**: Added comprehensive environment validation for Node.js, Flutter SDK, Firebase CLI versions, and project initialization (`.firebaserc`).
- **Cross-Platform Support**: Ensured consistent behavior across Windows (PowerShell/CMD), macOS, and Linux terminal environments.
- **Config Support**: Added `.fia.yaml` parsing to customize debounce timing, auto-deploy features, and interactivity.
- **Full CLI Suite**: Introduced `fia run`, `fia deploy`, `fia status`, and `fia export` commands.


