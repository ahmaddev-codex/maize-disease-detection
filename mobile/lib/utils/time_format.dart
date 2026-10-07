import 'package:intl/intl.dart';

// Scan timestamps are stored in UTC. Screens rendered them raw, so a 00:30 scan
// in Lagos showed as 23:30 the day before (T17). Convert here, in one place.

/// "11 Sep · 00:30" in the device timezone.
String formatScanTime(DateTime timestamp) =>
    DateFormat('d MMM · HH:mm').format(timestamp.toLocal());

/// "11 Sep 2026 · 00:30" in the device timezone.
String formatScanDateTime(DateTime timestamp) =>
    DateFormat('d MMM yyyy · HH:mm').format(timestamp.toLocal());

/// "2026-09-11" in the device timezone, used to bucket scans per day.
String localDayKey(DateTime timestamp) =>
    DateFormat('yyyy-MM-dd').format(timestamp.toLocal());
