class DateTimeHelper {
  // Parses an ISO 8601 string safely into a local DateTime.
  // If the parsed string is UTC (has 'Z' or offset), toLocal() converts it contextually.
  // If it is missing timezone data, it assumes local but forces standardization.
  static DateTime parseUtcToLocal(String value) {
    return DateTime.parse(value).toLocal();
  }

  // Normalizes any DateTime (regardless of UTC or Local state) into a strict Local Date
  // at 00:00:00 (year, month, day) for robust chronological sorting and grouping (like Calendar).
  static DateTime localDateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  // Serializes a DateTime aggressively into UTC ISO-8601 strings (with a 'Z' timezone).
  // Ensures the database receives a clean, timezone-declared timestamp.
  static String toUtcIso(DateTime value) {
    return value.toUtc().toIso8601String();
  }
}
