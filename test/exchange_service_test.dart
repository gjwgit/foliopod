/// Tests for ExchangeService conversion logic (rates injected).
///
// Run: flutter test test/exchange_service_test.dart

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/services/exchange_service.dart';

void main() {
  tearDown(() => ExchangeService.setRatesForTesting(null));

  group('toAud', () {
    test('AUD passes through unchanged without rates', () {
      ExchangeService.setRatesForTesting(null);
      expect(ExchangeService.toAud(100, 'AUD'), 100);
    });

    test('converts using AUD-based rates', () {
      // 1 AUD = 0.65 USD, so 65 USD = 100 AUD.
      ExchangeService.setRatesForTesting({'USD': 0.65, 'SGD': 0.88});
      expect(ExchangeService.toAud(65, 'USD'), closeTo(100, 1e-9));
      expect(ExchangeService.toAud(88, 'SGD'), closeTo(100, 1e-9));
    });

    test('unknown currency returns null', () {
      ExchangeService.setRatesForTesting({'USD': 0.65});
      expect(ExchangeService.toAud(10, 'THB'), isNull);
    });

    test('no rates yet returns null for foreign currencies', () {
      ExchangeService.setRatesForTesting(null);
      expect(ExchangeService.toAud(10, 'USD'), isNull);
    });

    test('zero rate is treated as unavailable, not a division', () {
      ExchangeService.setRatesForTesting({'USD': 0});
      expect(ExchangeService.toAud(10, 'USD'), isNull);
    });
  });

  group('rateFromAud', () {
    test('is the published AUD-based rate, inverse of toAud', () {
      ExchangeService.setRatesForTesting({'USD': 0.65});
      expect(ExchangeService.rateFromAud('USD'), 0.65);
      // Consistency: A\$1 buys 0.65 USD, and 0.65 USD is A\$1.
      expect(
        ExchangeService.toAud(ExchangeService.rateFromAud('USD')!, 'USD'),
        closeTo(1, 1e-9),
      );
    });

    test('AUD is 1 and unknown currencies are null', () {
      ExchangeService.setRatesForTesting({'USD': 0.65});
      expect(ExchangeService.rateFromAud('AUD'), 1);
      expect(ExchangeService.rateFromAud('THB'), isNull);
    });
  });

  group('ratesDate', () {
    test('reflects the injected publication date', () {
      ExchangeService.setRatesForTesting(
        {'USD': 0.65},
        date: DateTime(2026, 7, 28),
      );
      expect(ExchangeService.ratesDate, DateTime(2026, 7, 28));
      expect(ExchangeService.hasRates, isTrue);
    });
  });
}
