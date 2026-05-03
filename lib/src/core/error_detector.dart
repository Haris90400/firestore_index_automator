/// Scans flutter run logs for missing Firestore index URLs using a rolling buffer.
class ErrorDetector {
  final List<String> _buffer = [];
  final Set<String> _processedUrls = {};

  /// The regular expression used to find Firestore composite index URLs.
  final RegExp indexUrlRegex = RegExp(
    r'https://console\.firebase\.google\.com\s*'
    r'(?:/v1/r)?\s*'
    r'/\s*project/\s*([^/\s]+)'
    r'/\s*firestore/indexes\s*'
    r'\?create_composite=\s*([\w+/=_-]+)',
    caseSensitive: false,
    multiLine: true,
  );

  /// Feeds a new log line to the detector.
  /// Returns a full parsed URL if a new index error is detected, otherwise null.
  String? processLine(String line) {
    _buffer.add(line.trimRight());
    if (_buffer.length > 5) {
      _buffer.removeAt(0);
    }

    final joined = _buffer.join(' ');
    final match = indexUrlRegex.firstMatch(joined);

    if (match != null) {
      final url = match.group(0)!;
      // Strip out whitespace from the split URL
      final cleanUrl = url.replaceAll(RegExp(r'\s+'), '');

      if (!_processedUrls.contains(cleanUrl)) {
        _processedUrls.add(cleanUrl);
        return cleanUrl;
      }
    }
    return null;
  }

  /// Clears the processed URLs for testing or resetting session state
  void clear() {
    _buffer.clear();
    _processedUrls.clear();
  }
}
