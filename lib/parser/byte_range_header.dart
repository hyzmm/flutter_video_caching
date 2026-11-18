/// Parsed HTTP `Range` header for byte ranges.
///
/// Invalid or empty ranges are treated as absent so the proxy answers with
/// `200 OK` and the whole resource. Windows Media Foundation sends
/// `Range: -` while probing a URL; replying with a one-byte body makes it
/// treat the source as corrupt.
class ByteRangeHeader {
  const ByteRangeHeader._({this.start, this.end, this.suffixLength});

  final int? start;
  final int? end;
  final int? suffixLength;

  static const ByteRangeHeader none = ByteRangeHeader._();

  /// Whether the response should be `206 Partial Content`.
  bool get isPartial => start != null || suffixLength != null;

  static ByteRangeHeader parse(String? header) {
    if (header == null) return none;
    final match = RegExp(r'^bytes=\s*(\d*)\s*-\s*(\d*)\s*$')
        .firstMatch(header.trim());
    if (match == null) return none;
    final startText = match.group(1)!;
    final endText = match.group(2)!;
    if (startText.isEmpty && endText.isEmpty) return none;
    if (startText.isEmpty) {
      final suffix = int.tryParse(endText);
      if (suffix == null || suffix <= 0) return none;
      return ByteRangeHeader._(suffixLength: suffix);
    }
    final start = int.tryParse(startText);
    if (start == null) return none;
    final end = endText.isEmpty ? null : int.tryParse(endText);
    if (endText.isNotEmpty && end == null) return none;
    if (end != null && end < start) return none;
    return ByteRangeHeader._(start: start, end: end);
  }

  /// Resolves this header against [totalLength].
  ///
  /// Returns `null` when the range cannot be satisfied; callers should fall
  /// back to serving the whole resource.
  (int, int)? resolve(int totalLength) {
    if (totalLength <= 0) return null;
    if (suffixLength != null) {
      final start = totalLength - suffixLength!;
      return (start < 0 ? 0 : start, totalLength - 1);
    }
    final start = this.start;
    if (start == null || start >= totalLength) return null;
    final end = this.end;
    return (start, end == null || end >= totalLength ? totalLength - 1 : end);
  }
}
