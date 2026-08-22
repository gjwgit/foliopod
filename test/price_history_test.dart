/// Tests for the recorded share-price series and the change in value
/// since the start of the financial year.
///
// Run: flutter test test/price_history_test.dart

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/services/app_provider.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/portfolio_service.dart';
import 'package:foliopod/services/price_service.dart';

void main() {
  // The financial year containing "now", so tests are not tied to a date.
  final fyStart = Account.fyStart(DateTime.now());
  final beforeFY = fyStart.subtract(const Duration(days: 30));
  final afterFY = fyStart.add(const Duration(days: 10));

  tearDown(() {
    PriceService.setQuotesForTesting({});
    ExchangeService.setRatesForTesting(null);
  });

  AccountEvent priceAt(double price, DateTime date) => AccountEvent(
    date: date,
    type: AccountEventType.priceUpdate,
    price: price,
  );

  Account holding({double units = 100, double? openingPrice}) => Account.open(
    name: 'Microsoft',
    type: AccountType.shares,
    symbol: 'MSFT',
    currency: 'USD',
    openingBalance: units,
    price: openingPrice,
    date: beforeFY.subtract(const Duration(days: 30)),
  );

  // ── The price series ───────────────────────────────────────────────────────

  group('price entries', () {
    test('an opening price is recorded on the account', () {
      final a = holding(openingPrice: 300);
      expect(a.currentPrice, 300);
      expect(a.events.single.price, 300);
    });

    test('a price update sets the price and keeps the old one', () {
      final a = holding(openingPrice: 300).applyEvent(priceAt(412.5, afterFY));
      expect(a.currentPrice, 412.5);
      expect(a.events.last.previous, 300);
      // Units are untouched by a price update.
      expect(a.currentBalance, 100);
    });

    test('the description shows the new price only', () {
      final a = holding(openingPrice: 300).applyEvent(priceAt(412.5, afterFY));
      expect(
        a.events.last.describe(symbol: 'US\$', ticker: 'MSFT'),
        'Price US\$412.50',
      );
    });

    test('a replay recomputes the price from the entries', () {
      final a = holding(
        openingPrice: 300,
      ).applyEvent(priceAt(350, beforeFY)).applyEvent(priceAt(412.5, afterFY));
      final b = a.rebuilt(a.events);
      expect(b.currentPrice, 412.5);
      expect(b.events.last.previous, 350);
    });

    test('deleting the latest price entry reverts the price', () {
      final a = holding(
        openingPrice: 300,
      ).applyEvent(priceAt(350, beforeFY)).applyEvent(priceAt(412.5, afterFY));
      final last = a.events.last.id;
      final b = a.rebuilt(a.events.where((e) => e.id != last).toList());
      expect(b.currentPrice, 350);
    });
  });

  // ── As-at lookups ──────────────────────────────────────────────────────────

  group('as at a date', () {
    test('priceAt finds the last price recorded before the date', () {
      final a = holding(
        openingPrice: 300,
      ).applyEvent(priceAt(350, beforeFY)).applyEvent(priceAt(412.5, afterFY));
      expect(a.priceAt(fyStart), 350);
      expect(a.priceAt(DateTime.now()), 412.5);
    });

    test('priceAt ignores trade prices, which are not market marks', () {
      final a = holding(openingPrice: 300).applyEvent(
        AccountEvent(
          date: beforeFY,
          type: AccountEventType.buy,
          amount: 10,
          price: 999,
        ),
      );
      expect(a.priceAt(fyStart), 300);
    });

    test('balanceAt gives the units held before the date', () {
      final a = holding().applyEvent(
        AccountEvent(date: afterFY, type: AccountEventType.buy, amount: 50),
      );
      expect(a.balanceAt(fyStart), 100);
      expect(a.currentBalance, 150);
    });

    test('balanceAt is zero before the account existed', () {
      expect(holding().balanceAt(DateTime(2000)), 0);
    });
  });

  // ── Change since 1 July ────────────────────────────────────────────────────

  group('changeSinceFYStart', () {
    test('a cash account compares balances', () {
      final a =
          Account.open(
            name: 'Saver',
            openingBalance: 1000,
            date: beforeFY,
          ).applyEvent(
            AccountEvent(
              date: afterFY,
              type: AccountEventType.interest,
              amount: 40,
            ),
          );
      expect(PortfolioService.changeSinceFYStart(a), 40);
    });

    test('a shareholding compares units times price at each end', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 450, currency: 'USD', fetched: DateTime.now()),
      });
      final a = holding(openingPrice: 300).applyEvent(priceAt(400, beforeFY));
      // Was 100 x 400 = 40,000; now 100 x 450 = 45,000.
      expect(PortfolioService.changeSinceFYStart(a), 5000);
    });

    test('units bought during the year count towards the change', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 400, currency: 'USD', fetched: DateTime.now()),
      });
      final a = holding(openingPrice: 400).applyEvent(
        AccountEvent(
          date: afterFY,
          type: AccountEventType.buy,
          amount: 10,
          price: 400,
        ),
      );
      // 110 x 400 now against 100 x 400 then.
      expect(PortfolioService.changeSinceFYStart(a), 4000);
    });

    test('a holding with no price by 1 July cannot be compared', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 450, currency: 'USD', fetched: DateTime.now()),
      });
      // Opened before the FY but with no price recorded until after it.
      final a = holding().applyEvent(priceAt(400, afterFY));
      expect(a.priceAt(fyStart), isNull);
      expect(PortfolioService.changeSinceFYStart(a), isNull);
    });

    test('an account opened during the year counts its whole value', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 400, currency: 'USD', fetched: DateTime.now()),
      });
      final a = Account.open(
        name: 'New Holding',
        type: AccountType.shares,
        symbol: 'MSFT',
        currency: 'USD',
        openingBalance: 10,
        price: 380,
        date: afterFY,
      );
      // Nothing held at 1 July, so the change is the current value.
      expect(PortfolioService.changeSinceFYStart(a), 4000);
    });
  });

  // ── Automatic recording ────────────────────────────────────────────────────

  group('recordPriceUpdates', () {
    AppProvider providerWith(List<Account> accounts) {
      final p = AppProvider();
      p.loadTestData(accounts: accounts);
      return p;
    }

    test('records an entry when the fetched price has moved', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 412.5, currency: 'USD', fetched: DateTime.now()),
      });
      final p = providerWith([holding(openingPrice: 300)]);
      expect(p.recordPriceUpdates(), 1);
      final a = p.allAccounts.single;
      expect(a.currentPrice, 412.5);
      expect(a.events.last.type, AccountEventType.priceUpdate);
      expect(a.events.last.previous, 300);
    });

    test('records nothing when the price is unchanged', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 300, currency: 'USD', fetched: DateTime.now()),
      });
      final p = providerWith([holding(openingPrice: 300)]);
      expect(p.recordPriceUpdates(), 0);
      expect(p.allAccounts.single.events, hasLength(1));
    });

    test('records a first price for a holding that had none', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 300, currency: 'USD', fetched: DateTime.now()),
      });
      final p = providerWith([holding()]);
      expect(p.recordPriceUpdates(), 1);
      expect(p.allAccounts.single.currentPrice, 300);
    });

    test('leaves cash accounts and unpriced holdings alone', () {
      PriceService.setQuotesForTesting({});
      final p = providerWith([
        holding(openingPrice: 300),
        Account.open(name: 'Saver', openingBalance: 10, date: beforeFY),
      ]);
      expect(p.recordPriceUpdates(), 0);
    });

    test('repeated calls with the same price add nothing further', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 412.5, currency: 'USD', fetched: DateTime.now()),
      });
      final p = providerWith([holding(openingPrice: 300)]);
      expect(p.recordPriceUpdates(), 1);
      expect(p.recordPriceUpdates(), 0);
      expect(p.allAccounts.single.events, hasLength(2));
    });

    test('only one mark is recorded per day, however often it moves', () {
      final p = providerWith([holding(openingPrice: 300)]);
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 410, currency: 'USD', fetched: DateTime.now()),
      });
      expect(p.recordPriceUpdates(), 1);
      // The price moves again later the same day.
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 425, currency: 'USD', fetched: DateTime.now()),
      });
      expect(p.recordPriceUpdates(), 0);
      expect(p.allAccounts.single.events, hasLength(2));
      // The day's mark stays the first one recorded.
      expect(p.allAccounts.single.currentPrice, 410);
    });

    test('a fresh mark is recorded the next day', () {
      final p = providerWith([holding(openingPrice: 300)]);
      final today = DateTime.now();
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 410, currency: 'USD', fetched: today),
      });
      expect(p.recordPriceUpdates(at: today), 1);
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 425, currency: 'USD', fetched: today),
      });
      expect(p.recordPriceUpdates(at: today.add(const Duration(days: 1))), 1);
      expect(p.allAccounts.single.currentPrice, 425);
      expect(p.allAccounts.single.events, hasLength(3));
    });

    test('an account opened today already counts as marked', () {
      PriceService.setQuotesForTesting({
        'MSFT': Quote(price: 500, currency: 'USD', fetched: DateTime.now()),
      });
      final opened = Account.open(
        name: 'New Holding',
        type: AccountType.shares,
        symbol: 'MSFT',
        currency: 'USD',
        openingBalance: 5,
        price: 480,
        date: DateTime.now(),
      );
      final p = providerWith([opened]);
      expect(p.recordPriceUpdates(), 0);
      // The value shown still uses the freshest fetched price.
      expect(PortfolioService.priceFor(p.allAccounts.single), 500);
    });
  });
}
