/// Tests for PortfolioService — valuing cash and share accounts.
///
// Run: flutter test test/portfolio_service_test.dart

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/portfolio_service.dart';
import 'package:foliopod/services/price_service.dart';

void main() {
  setUp(() {
    // 1 AUD = 0.65 USD, so US$1 is about A$1.538.
    ExchangeService.setRatesForTesting({'USD': 0.65});
    PriceService.setQuotesForTesting({
      'MSFT': Quote(price: 400, currency: 'USD', fetched: DateTime.now()),
    });
  });

  tearDown(() {
    ExchangeService.setRatesForTesting(null);
    PriceService.setQuotesForTesting({});
  });

  Account shares({
    String symbol = 'MSFT',
    double units = 100,
    String currency = 'USD',
    double? manualPrice,
  }) => Account(
    name: 'Microsoft',
    type: AccountType.shares,
    symbol: symbol,
    currency: currency,
    currentBalance: units,
    manualPrice: manualPrice,
  );

  group('cash accounts', () {
    test('native value is the balance and AUD converts', () {
      final a = Account(name: 'Saver', currency: 'USD', currentBalance: 65);
      expect(PortfolioService.nativeValue(a), 65);
      expect(PortfolioService.audValue(a), closeTo(100, 1e-9));
      expect(PortfolioService.priceFor(a), isNull);
    });
  });

  group('shareholdings', () {
    test('value is units times the market price, then in AUD', () {
      final a = shares();
      // 100 x US$400 = US$40,000 -> A$40,000 / 0.65.
      expect(PortfolioService.nativeValue(a), 40000);
      expect(PortfolioService.audValue(a), closeTo(40000 / 0.65, 1e-6));
    });

    test('a fetched price takes precedence over the fallback', () {
      expect(PortfolioService.priceFor(shares(manualPrice: 111)), 400);
    });

    test('the fallback price is used when no quote is available', () {
      PriceService.setQuotesForTesting({});
      final a = shares(manualPrice: 300);
      expect(PortfolioService.priceFor(a), 300);
      expect(PortfolioService.nativeValue(a), 30000);
    });

    test('no price at all leaves the value unknown', () {
      PriceService.setQuotesForTesting({});
      final a = shares();
      expect(PortfolioService.nativeValue(a), isNull);
      expect(PortfolioService.audValue(a), isNull);
    });

    test('an unavailable exchange rate leaves the AUD value unknown', () {
      ExchangeService.setRatesForTesting(null);
      expect(PortfolioService.nativeValue(shares()), 40000);
      expect(PortfolioService.audValue(shares()), isNull);
    });

    test('symbol lookup is case insensitive', () {
      expect(PortfolioService.priceFor(shares(symbol: 'msft')), 400);
    });

    test('an AUD holding needs no conversion', () {
      PriceService.setQuotesForTesting({
        'CBA.AX': Quote(price: 170, currency: 'AUD', fetched: DateTime.now()),
      });
      final a = shares(symbol: 'CBA.AX', units: 10, currency: 'AUD');
      expect(PortfolioService.audValue(a), 1700);
    });
  });
}
