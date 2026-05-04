import 'package:apix/apix.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coverage of `RetryInterceptor.parseRetryAfter` — exposed in apix v2.1.0
/// for both production use and deterministic testing.
void main() {
  group('RetryInterceptor.parseRetryAfter', () {
    test('delta-seconds: positive integer', () {
      expect(
        RetryInterceptor.parseRetryAfter('60'),
        const Duration(seconds: 60),
      );
    });

    test('delta-seconds: surrounding whitespace', () {
      expect(
        RetryInterceptor.parseRetryAfter('  5  '),
        const Duration(seconds: 5),
      );
    });

    test('delta-seconds: negative is clamped to zero', () {
      expect(RetryInterceptor.parseRetryAfter('-10'), Duration.zero);
    });

    test('HTTP-date: future timestamp', () {
      final now = DateTime.utc(2026, 5, 4, 12, 0, 0);
      final inOneMinute = now.add(const Duration(minutes: 1));
      // Format: "Mon, 04 May 2026 12:01:00 GMT"
      final header = _httpDate(inOneMinute);

      final parsed = RetryInterceptor.parseRetryAfter(header, now: now);

      expect(parsed, isNotNull);
      expect(parsed!.inSeconds, inInclusiveRange(59, 61));
    });

    test('HTTP-date: past timestamp clamps to zero', () {
      final now = DateTime.utc(2026, 5, 4, 12, 0, 0);
      final pastDate = now.subtract(const Duration(minutes: 5));

      final parsed = RetryInterceptor.parseRetryAfter(
        _httpDate(pastDate),
        now: now,
      );

      expect(parsed, Duration.zero);
    });

    test('Garbage value returns null (caller falls back to backoff)', () {
      expect(RetryInterceptor.parseRetryAfter('not-a-thing'), isNull);
      expect(RetryInterceptor.parseRetryAfter(''), isNull);
    });
  });
}

/// Formats a [DateTime] as an HTTP-date (RFC 7231 §7.1.1.1).
String _httpDate(DateTime dt) {
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final utc = dt.toUtc();
  final day = dayNames[utc.weekday - 1];
  final month = monthNames[utc.month - 1];
  return '$day, ${_two(utc.day)} $month ${utc.year} '
      '${_two(utc.hour)}:${_two(utc.minute)}:${_two(utc.second)} GMT';
}

String _two(int n) => n.toString().padLeft(2, '0');
