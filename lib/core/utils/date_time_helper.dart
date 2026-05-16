class DateTimeHelper {
  // Parse an ISO string into local time.
  static DateTime parseUtcToLocal(String value) {
    return DateTime.parse(value).toLocal();
  }

  // Keep only the local date part.
  static DateTime localDateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  // Convert to UTC ISO string.
  static String toUtcIso(DateTime value) {
    return value.toUtc().toIso8601String();
  }
}
