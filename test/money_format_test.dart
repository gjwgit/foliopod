/// Tests for the money formatting and comma-tolerant parsing helpers.
///
// Run: flutter test test/money_format_test.dart

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/services/money_format.dart';

void main() {
  group('formatMoney', () {
    test('thousands separators and two decimals', () {
      expect(formatMoney(1234567.891), '1,234,567.89');
      expect(formatMoney(1000), '1,000.00');
      expect(formatMoney(9.5), '9.50');
      expect(formatMoney(0), '0.00');
    });
  });

  group('parseNum', () {
    test('plain numbers parse', () {
      expect(parseNum('1234.56'), 1234.56);
      expect(parseNum('25'), 25);
    });

    test('commas are stripped', () {
      expect(parseNum('1,234.56'), 1234.56);
      expect(parseNum('12,345,678.90'), 12345678.90);
    });

    test('surrounding whitespace is tolerated', () {
      expect(parseNum(' 1,000 '), 1000);
    });

    test('round-trips its own formatting', () {
      expect(parseNum(formatMoney(1234567.89)), 1234567.89);
    });

    test('non-numbers return null', () {
      expect(parseNum(''), isNull);
      expect(parseNum('abc'), isNull);
      expect(parseNum('\$100'), isNull);
    });
  });
}
