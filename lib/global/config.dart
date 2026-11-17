import 'package:flutter/foundation.dart';

/// A global configuration class for application-wide settings.
class Config {
  /// Indicates whether the app is running in debug mode.
  static const bool isDebug = kDebugMode;

  /// Controls whether log output is enabled.
  /// Can be toggled at runtime.
  static bool logPrint = false;

  /// The server IP address used for network requests.
  static String ip = '127.0.0.1';

  /// The server port used for network requests.
  static int port = 20250;

  /// Returns the server URL in the format "ip:port".
  static String get serverUrl => "$ip:$port";

  /// The size of one megabyte in bytes.
  static int mbSize = 1000 * 1000;

  /// The size of one gigabyte in bytes.
  static int gbSize = 1000 * mbSize;

  /// The maximum size for in-memory cache (in bytes).
  /// Default is 100MB.
  static int memoryCacheSize = 100 * mbSize; // 100MB

  /// The maximum size for storage cache (in bytes).
  /// Default is 1GB.
  static int storageCacheSize = 1 * gbSize; // 1GB

  /// The size of each data segment (in bytes) for chunked operations.
  static int segmentSize = 2000000;

  /// When set (> 0 and < [segmentSize]), the first [segmentSize] bytes of a
  /// file are split into segments of this size for faster first-byte delivery;
  /// everything past [segmentSize] stays [segmentSize]-aligned. 0 = uniform.
  static int firstSegmentSize = 0;

  static bool get _hybrid =>
      firstSegmentSize > 0 && firstSegmentSize < segmentSize;

  /// Start of the segment containing [position].
  static int segmentStartOf(int position) {
    final unit = _hybrid && position < segmentSize
        ? firstSegmentSize
        : segmentSize;
    return position - position % unit;
  }

  /// End (exclusive) of the segment starting at [start].
  static int segmentEndOf(int start) {
    if (_hybrid && start < segmentSize) {
      final end = start + firstSegmentSize;
      return end < segmentSize ? end : segmentSize;
    }
    return start + segmentSize;
  }

  /// Number of segments covering a file of [contentLength] bytes.
  static int segmentCount(int contentLength) {
    var count = 0;
    for (var start = 0; start < contentLength; start = segmentEndOf(start)) {
      count++;
    }
    return count;
  }

  /// A custom cache identifier string.
  static String customCacheId = 'Custom-Cache-ID';
}
