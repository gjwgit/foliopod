/// Tests for superannuation accounts: contributions in, investment
/// earnings that may be negative, and fees out.
///
// Run: flutter test test/superannuation_test.dart

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/services/portfolio_service.dart';

void main() {
  final fyStart = Account.fyStart(DateTime.now());
  final beforeFY = fyStart.subtract(const Duration(days: 60));
  final afterFY = fyStart.add(const Duration(days: 10));

  Account fund({double opening = 100000, DateTime? date}) => Account.open(
    name: 'Test Super',
    institution: 'Fund Co',
    type: AccountType.superannuation,
    openingBalance: opening,
    date: date ?? beforeFY,
  );

  AccountEvent entry(AccountEventType type, double amount, {DateTime? date}) =>
      AccountEvent(date: date ?? afterFY, type: type, amount: amount);

  // ── Applying entries ───────────────────────────────────────────────────────

  group('entries', () {
    test('a contribution adds to the balance', () {
      final a = fund().applyEvent(entry(AccountEventType.contribution, 1200));
      expect(a.currentBalance, 101200);
      expect(a.events.last.balance, 101200);
    });

    test('earnings add and count as income for the year', () {
      final a = fund().applyEvent(entry(AccountEventType.earnings, 5000));
      expect(a.currentBalance, 105000);
      expect(a.earned(), 5000);
      expect(a.interestFY, 5000);
    });

    test('a loss is a negative earnings entry', () {
      final a = fund().applyEvent(entry(AccountEventType.earnings, -2500));
      expect(a.currentBalance, 97500);
      expect(a.earned(), -2500);
    });

    test('a fee comes off the balance and is not income', () {
      final a = fund().applyEvent(entry(AccountEventType.fee, 320));
      expect(a.currentBalance, 99680);
      expect(a.earned(), 0);
    });

    test('a contribution is not counted as income', () {
      final a = fund().applyEvent(entry(AccountEventType.contribution, 1200));
      expect(a.earned(), 0);
    });

    test('a statement replays to the fund balance', () {
      final a = fund()
          .applyEvent(entry(AccountEventType.contribution, 1200))
          .applyEvent(entry(AccountEventType.earnings, 5000))
          .applyEvent(entry(AccountEventType.fee, 320));
      expect(a.currentBalance, 105880);
      expect(a.earned(), 5000);
      // Editing the earnings entry recomputes everything after it.
      final edited = a.events[2].copyWith(amount: 6000.0);
      final b = a.rebuilt([
        for (final e in a.events)
          if (e.id == edited.id) edited else e,
      ]);
      expect(b.currentBalance, 106880);
    });
  });

  // ── Descriptions ───────────────────────────────────────────────────────────

  group('descriptions', () {
    test('a contribution and a fee read plainly', () {
      expect(
        entry(AccountEventType.contribution, 1200).description,
        'Contribution \$1,200.00',
      );
      expect(entry(AccountEventType.fee, 320).description, 'Fee \$320.00');
    });

    test('a loss carries its sign', () {
      expect(
        entry(AccountEventType.earnings, -2500).description,
        'Earnings −\$2,500.00',
      );
      expect(
        entry(AccountEventType.earnings, 5000).description,
        'Earnings \$5,000.00',
      );
    });
  });

  // ── Presentation ───────────────────────────────────────────────────────────

  group('presentation', () {
    test('income is called earnings', () {
      expect(fund().incomeLabel, 'earnings');
      expect(fund().isSuper, isTrue);
      expect(fund().isShares, isFalse);
    });

    test('the balance shows as money, not units', () {
      expect(fund(opening: 100000).holdingStr, '\$100,000.00');
    });
  });

  // ── Change since 1 July ────────────────────────────────────────────────────

  group('change since 1 July', () {
    test('covers contributions, earnings and fees for the year', () {
      final a = fund()
          .applyEvent(entry(AccountEventType.contribution, 1200))
          .applyEvent(entry(AccountEventType.earnings, 5000))
          .applyEvent(entry(AccountEventType.fee, 320));
      expect(PortfolioService.changeSinceFYStart(a), 5880);
    });

    test('a fund opened during the year counts its whole balance', () {
      final a = fund(opening: 5000, date: afterFY);
      expect(PortfolioService.changeSinceFYStart(a), 5000);
    });
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  group('serialisation', () {
    test('the type and its entries round-trip', () {
      final a = fund()
          .applyEvent(entry(AccountEventType.contribution, 1200))
          .applyEvent(entry(AccountEventType.earnings, -2500))
          .applyEvent(entry(AccountEventType.fee, 320));
      final b = Account.fromJson(a.toJson());
      expect(b.type, AccountType.superannuation);
      expect(b.currentBalance, a.currentBalance);
      expect(
        b.events.map((e) => e.type),
        containsAll([
          AccountEventType.contribution,
          AccountEventType.earnings,
          AccountEventType.fee,
        ]),
      );
      expect(b.earned(), -2500);
    });
  });
}
