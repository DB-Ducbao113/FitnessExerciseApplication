import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Performance and payload stats comparing raw JSON coordinates to encoded polyline.
class PolylineCompressionStats {
  /// Estimated size of the raw JSON array in bytes.
  final int rawJsonSizeBytes;

  /// Exact size of the encoded polyline string in bytes (UTF-8).
  final int encodedSizeBytes;

  /// Compression ratio percentage (e.g. 96.5% reduction).
  final double savedBytesPercentage;

  /// Compression factor (e.g. 28.5x smaller).
  final double compressionFactor;

  /// Total number of coordinates analyzed.
  final int coordinateCount;

  const PolylineCompressionStats({
    required this.rawJsonSizeBytes,
    required this.encodedSizeBytes,
    required this.savedBytesPercentage,
    required this.compressionFactor,
    required this.coordinateCount,
  });

  @override
  String toString() {
    return 'PolylineCompressionStats('
        'coordinates: $coordinateCount, '
        'rawJson: ${(rawJsonSizeBytes / 1024).toStringAsFixed(2)} KB, '
        'encoded: ${(encodedSizeBytes / 1024).toStringAsFixed(2)} KB, '
        'saved: ${savedBytesPercentage.toStringAsFixed(1)}%, '
        'factor: ${compressionFactor.toStringAsFixed(1)}x smaller)';
  }
}

/// Industrial-grade Google Encoded Polyline Algorithm Service.
///
/// Implements standard lossy geometric compression for GPS routes.
/// Compresses coordinate lists by 90% - 96% compared to raw JSON arrays.
/// Compatible with Google Maps, Strava, Mapbox, Leaflet, and Garmin GPX formats.
class PolylineCompressionService {
  const PolylineCompressionService();

  /// Default precision: 5 decimal places (~1.1 meters accuracy at equator).
  static const int kDefaultPrecision = 5;

  /// High precision: 6 decimal places (~0.11 meters accuracy).
  static const int kHighPrecision = 6;

  /// Encodes a list of [LatLng] coordinates into a Google Encoded Polyline string.
  ///
  /// [precision] defaults to 5 decimal places (Google Maps standard).
  String encode(List<LatLng> points, {int precision = kDefaultPrecision}) {
    if (points.isEmpty) return '';

    final factor = _precisionFactor(precision);
    final buffer = StringBuffer();

    var prevLat = 0;
    var prevLng = 0;

    for (final point in points) {
      final lat = (point.latitude * factor).round();
      final lng = (point.longitude * factor).round();

      final deltaLat = lat - prevLat;
      final deltaLng = lng - prevLng;

      prevLat = lat;
      prevLng = lng;

      _encodeSignedNumber(deltaLat, buffer);
      _encodeSignedNumber(deltaLng, buffer);
    }

    return buffer.toString();
  }

  /// Decodes a Google Encoded Polyline string back into a list of [LatLng].
  ///
  /// [precision] must match the precision used during encoding (default 5).
  List<LatLng> decode(
    String encoded, {
    int precision = kDefaultPrecision,
  }) {
    if (encoded.isEmpty) return const <LatLng>[];

    final factor = _precisionFactor(precision);
    final points = <LatLng>[];

    var index = 0;
    final len = encoded.length;
    var lat = 0;
    var lng = 0;

    while (index < len) {
      final deltaLat = _decodeSignedNumber(encoded, index);
      lat += deltaLat.value;
      index = deltaLat.nextIndex;

      if (index >= len) break;

      final deltaLng = _decodeSignedNumber(encoded, index);
      lng += deltaLng.value;
      index = deltaLng.nextIndex;

      points.add(LatLng(lat / factor, lng / factor));
    }

    return points;
  }

  /// Encodes multiple route segments (e.g. separated by GPS dropouts or pauses).
  List<String> encodeSegments(
    List<List<LatLng>> segments, {
    int precision = kDefaultPrecision,
  }) {
    return segments
        .where((seg) => seg.isNotEmpty)
        .map((seg) => encode(seg, precision: precision))
        .toList(growable: false);
  }

  /// Decodes a list of encoded segment strings into multiple [LatLng] segments.
  List<List<LatLng>> decodeSegments(
    List<String> encodedSegments, {
    int precision = kDefaultPrecision,
  }) {
    return encodedSegments
        .map((seg) => decode(seg, precision: precision))
        .where((seg) => seg.isNotEmpty)
        .toList(growable: false);
  }

  /// Calculates empirical compression statistics comparing raw JSON coordinates to encoded polyline.
  PolylineCompressionStats calculateCompressionStats({
    required List<LatLng> originalPoints,
    required String encodedPolyline,
  }) {
    if (originalPoints.isEmpty) {
      return const PolylineCompressionStats(
        rawJsonSizeBytes: 0,
        encodedSizeBytes: 0,
        savedBytesPercentage: 0.0,
        compressionFactor: 1.0,
        coordinateCount: 0,
      );
    }

    // Typical JSON array representation: [{"latitude":10.77688,"longitude":106.70080},...]
    final rawJsonString = jsonEncode(
      originalPoints
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList(growable: false),
    );
    final rawBytes = utf8.encode(rawJsonString).length;
    final encodedBytes = utf8.encode(encodedPolyline).length;

    final savedBytes = rawBytes > encodedBytes ? rawBytes - encodedBytes : 0;
    final savedPercentage = rawBytes > 0 ? (savedBytes / rawBytes) * 100.0 : 0.0;
    final factor = encodedBytes > 0 ? (rawBytes / encodedBytes) : 1.0;

    return PolylineCompressionStats(
      rawJsonSizeBytes: rawBytes,
      encodedSizeBytes: encodedBytes,
      savedBytesPercentage: savedPercentage,
      compressionFactor: factor,
      coordinateCount: originalPoints.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal Math & Encoding Helpers
  // ---------------------------------------------------------------------------

  double _precisionFactor(int precision) {
    switch (precision) {
      case 5:
        return 1e5;
      case 6:
        return 1e6;
      case 7:
        return 1e7;
      default:
        var result = 1.0;
        for (var i = 0; i < precision; i++) {
          result *= 10.0;
        }
        return result;
    }
  }

  void _encodeSignedNumber(int num, StringBuffer buffer) {
    var sgnNum = num < 0 ? ~(num << 1) : (num << 1);
    while (sgnNum >= 0x20) {
      final nextVal = (0x20 | (sgnNum & 0x1f)) + 63;
      buffer.writeCharCode(nextVal);
      sgnNum >>= 5;
    }
    buffer.writeCharCode(sgnNum + 63);
  }

  _DecodedValue _decodeSignedNumber(String str, int startIndex) {
    var result = 0;
    var shift = 0;
    var index = startIndex;

    while (index < str.length) {
      final byte = str.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) break;
    }

    final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return _DecodedValue(value: value, nextIndex: index);
  }
}

class _DecodedValue {
  final int value;
  final int nextIndex;

  const _DecodedValue({required this.value, required this.nextIndex});
}
