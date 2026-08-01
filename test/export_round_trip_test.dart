/// Tests that everything survives an export and re-import.
///
/// These mirror the exact code path in ImportScreen: the accounts are
/// encoded to a JSON list, decoded again, and rebuilt with
/// Account.fromJson. Every field is asserted individually so that a
/// field added to the model without being added to toJson/fromJson
/// fails here rather than going quietly missing from people's backups.
/// 20260730 gjw
///
// Run: flutter test test/export_round_trip_test.dart

library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';

void main() {
  /// Encode then decode exactly as export and import do.
  List<Account> roundTrip(List<Account> accounts) {
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    final decoded = jsonDecode(encoded) as List;
    return decoded
        .map((j) => Account.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  void expectSameEvent(AccountEvent a, AccountEvent b) {
    expect(b.id, a.id);
    expect(b.date, a.date);
    expect(b.type, a.type);
    expect(b.amount, a.amount);
    expect(b.bonus, a.bonus);
    expect(b.price, a.price);
    expect(b.rate, a.rate);
    expect(b.previous, a.previous);
    expect(b.balance, a.balance);
    expect(b.note, a.note);
  }

  void expectSameAccount(Account a, Account b) {
    expect(b.id, a.id);
    expect(b.name, a.name);
    expect(b.institution, a.institution);
    expect(b.type, a.type);
    expect(b.number, a.number);
    expect(b.symbol, a.symbol);
    expect(b.currentPrice, a.currentPrice);
    expect(b.manualPrice, a.manualPrice);
    expect(b.currency, a.currency);
    expect(b.currentBalance, a.currentBalance);
    expect(b.currentRate, a.currentRate);
    expect(b.isClosed, a.isClosed);
    expect(b.note, a.note);
    expect(b.events, hasLength(a.events.length));
    for (var i = 0; i < a.events.length; i++) {
      expectSameEvent(a.events[i], b.events[i]);
    }
  }

  // ── Cash accounts ──────────────────────────────────────────────────────────

  group('cash account', () {
    test('a foreign-currency account keeps its currency', () {
      final a =
          Account.open(
            name: 'US Saver',
            institution: 'Test Bank',
            type: AccountType.savings,
            number: '062-000 1234',
            currency: 'USD',
            openingBalance: 1000,
            rate: 4.0,
            date: DateTime(2026, 1, 1),
            note: 'Offshore',
          ).applyEvent(
            AccountEvent(
              date: DateTime(2026, 2, 1),
              type: AccountEventType.interest,
              amount: 10,
              bonus: 5,
              note: 'Bonus met',
            ),
          );
      final b = roundTrip([a]).single;
      expect(b.currency, 'USD');
      expect(b.balanceStr, startsWith('US\$'));
      expectSameAccount(a, b);
    });

    test('an AUD account still records its currency explicitly', () {
      final a = Account.open(
        name: 'Everyday',
        openingBalance: 10,
        date: DateTime(2026, 1, 1),
      );
      expect(a.toJson()['currency'], 'AUD');
      expectSameAccount(a, roundTrip([a]).single);
    });

    test('a closed account stays closed', () {
      final a = Account.open(
        name: 'Old',
        openingBalance: 1,
        date: DateTime(2026, 1, 1),
      ).copyWith(isClosed: true);
      expect(roundTrip([a]).single.isClosed, isTrue);
    });
  });

  // ── Shareholdings ──────────────────────────────────────────────────────────

  group('shareholding', () {
    Account holding() =>
        Account.open(
              name: 'Microsoft',
              institution: 'Broker',
              type: AccountType.shares,
              symbol: 'MSFT',
              currency: 'USD',
              openingBalance: 100,
              price: 395.5,
              date: DateTime(2026, 1, 1),
              note: 'Long term',
            )
            .applyEvent(
              AccountEvent(
                date: DateTime(2026, 2, 1),
                type: AccountEventType.buy,
                amount: 50,
                price: 420.25,
                note: 'Topped up',
              ),
            )
            .applyEvent(
              AccountEvent(
                date: DateTime(2026, 3, 1),
                type: AccountEventType.sell,
                amount: 20,
                price: 431,
              ),
            )
            .applyEvent(
              AccountEvent(
                date: DateTime(2026, 4, 1),
                type: AccountEventType.dividend,
                amount: 120,
              ),
            )
            .applyEvent(
              AccountEvent(
                date: DateTime(2026, 5, 1),
                type: AccountEventType.priceUpdate,
                price: 455.75,
              ),
            );

    test('symbol, units, fallback price and trades all survive', () {
      final a = holding();
      final b = roundTrip([a]).single;
      expect(b.type, AccountType.shares);
      expect(b.symbol, 'MSFT');
      expect(b.currentPrice, 455.75);
      expect(b.currency, 'USD');
      // 100 opening + 50 bought - 20 sold; the dividend leaves units be.
      expect(b.currentBalance, 130);
      expect(b.isShares, isTrue);
      expect(b.holdingStr, '130 MSFT');
      expectSameAccount(a, b);
    });

    test('per-trade prices survive', () {
      final b = roundTrip([holding()]).single;
      final buy = b.events.firstWhere((e) => e.type == AccountEventType.buy);
      final sell = b.events.firstWhere((e) => e.type == AccountEventType.sell);
      expect(buy.price, 420.25);
      expect(sell.price, 431);
    });

    test('the recorded price series survives', () {
      final b = roundTrip([holding()]).single;
      expect(b.currentPrice, 455.75);
      final update = b.events.firstWhere(
        (e) => e.type == AccountEventType.priceUpdate,
      );
      expect(update.price, 455.75);
      // The price it replaced is the opening price.
      expect(update.previous, 395.5);
    });

    test('dividends still count as income after a round trip', () {
      expect(roundTrip([holding()]).single.earned(), 120);
    });

    test('the imported history replays to the same figures', () {
      final b = roundTrip([holding()]).single;
      expect(b.rebuilt(b.events).currentBalance, b.currentBalance);
    });
  });

  // ── Mixed portfolio ────────────────────────────────────────────────────────

  group('whole portfolio', () {
    test('a mixed set of accounts round-trips intact', () {
      final accounts = [
        Account.open(
          name: 'Saver',
          openingBalance: 5000,
          rate: 4.35,
          date: DateTime(2026, 1, 1),
        ),
        Account.open(
          name: 'SG Cash',
          currency: 'SGD',
          openingBalance: 900,
          date: DateTime(2026, 1, 1),
        ),
        Account.open(
          name: 'Microsoft',
          type: AccountType.shares,
          symbol: 'MSFT',
          currency: 'USD',
          openingBalance: 100,
          date: DateTime(2026, 1, 1),
        ),
      ];
      final back = roundTrip(accounts);
      expect(back, hasLength(3));
      for (var i = 0; i < accounts.length; i++) {
        expectSameAccount(accounts[i], back[i]);
      }
      expect(back.map((a) => a.currency), ['AUD', 'SGD', 'USD']);
    });
  });

  // ── Backwards compatibility ────────────────────────────────────────────────

  group('older backups', () {
    test('a backup without currency imports as AUD', () {
      final j = Account.open(
        name: 'Legacy',
        openingBalance: 100,
        date: DateTime(2026, 1, 1),
      ).toJson()..remove('currency');
      expect(Account.fromJson(j).currency, 'AUD');
    });

    test('a backup with the old income type imports as deposit', () {
      final a =
          Account.open(
            name: 'Legacy',
            openingBalance: 100,
            date: DateTime(2026, 1, 1),
          ).applyEvent(
            AccountEvent(
              date: DateTime(2026, 2, 1),
              type: AccountEventType.deposit,
              amount: 50,
            ),
          );
      final j = a.toJson();
      (j['events'] as List)[1]['type'] = 'income';
      final b = Account.fromJson(j);
      expect(b.events.last.type, AccountEventType.deposit);
      expect(b.currentBalance, 150);
    });
  });
}
