import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:maizeguard/utils/time_format.dart';

/// T17: scans are stored in UTC and were rendered raw, so a 00:30 scan in Lagos
/// displayed as 23:30 the previous day. Note: these comparisons only *prove* the
/// conversion on a machine whose timezone is not UTC.
void main() {
  final storedUtc = DateTime.utc(2026, 9, 10, 23, 30);

  test('short form renders a stored UTC timestamp in local time', () {
    expect(formatScanTime(storedUtc), DateFormat('d MMM · HH:mm').format(storedUtc.toLocal()));
  });

  test('long form renders a stored UTC timestamp in local time', () {
    expect(formatScanDateTime(storedUtc),
        DateFormat('d MMM yyyy · HH:mm').format(storedUtc.toLocal()));
  });

  test('a timestamp already in local time is not shifted again', () {
    final local = DateTime(2026, 9, 10, 8, 15);
    expect(formatScanTime(local), DateFormat('d MMM · HH:mm').format(local));
  });

  test('local day key follows the device timezone', () {
    expect(localDayKey(storedUtc), DateFormat('yyyy-MM-dd').format(storedUtc.toLocal()));
  });
}
