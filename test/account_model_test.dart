/// Tests for the Account and AccountEvent models.
///
// Run: flutter test test/account_model_test.dart

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  Account open({double balance = 1000, double rate = 4.0}) => Account.open(
    name: 'Saver',
    institution: 'Test Bank',
    openingBalance: balance,
    rate: rate,
    date: DateTime(2026, 1, 1),
  );

  AccountEvent ev(
    AccountEventType type, {
    double? amount,
    double? rate,
    DateTime? date,
    String? note,
  }) => AccountEvent(
    date: date ?? DateTime(2026, 2, 1),
    type: type,
    amount: amount,
    rate: rate,
    note: note,
  );

  // ── Account.open ───────────────────────────────────────────────────────────

  group('Account.open', () {
    test('sets balance and rate and records a created event', () {
      final a = open();
      expect(a.currentBalance, 1000);
      expect(a.currentRate, 4.0);
      expect(a.events, hasLength(1));
      expect(a.events.first.type, AccountEventType.created);
      expect(a.events.first.balance, 1000);
    });
  });

  // ── applyEvent ─────────────────────────────────────────────────────────────

  group('applyEvent', () {
    test('interest adds to balance and records resulting balance', () {
      final a = open().applyEvent(ev(AccountEventType.interest, amount: 12.34));
      expect(a.currentBalance, closeTo(1012.34, 0.001));
      expect(a.events.last.balance, closeTo(1012.34, 0.001));
    });

    test('deposit adds to balance', () {
      final a = open().applyEvent(ev(AccountEventType.deposit, amount: 50));
      expect(a.currentBalance, 1050);
    });

    test('rate change updates rate and keeps old rate as previous', () {
      final a = open().applyEvent(ev(AccountEventType.rateChange, rate: 4.35));
      expect(a.currentRate, 4.35);
      expect(a.events.last.previous, 4.0);
      // Balance is unchanged by a rate change.
      expect(a.currentBalance, 1000);
    });

    test('balance update sets balance and keeps old balance', () {
      final a = open().applyEvent(
        ev(AccountEventType.balanceUpdate, amount: 999.99),
      );
      expect(a.currentBalance, 999.99);
      expect(a.events.last.previous, 1000);
    });

    test('events accumulate in order', () {
      final a = open()
          .applyEvent(ev(AccountEventType.interest, amount: 10))
          .applyEvent(ev(AccountEventType.rateChange, rate: 5))
          .applyEvent(ev(AccountEventType.interest, amount: 20));
      expect(a.events, hasLength(4));
      expect(a.currentBalance, 1030);
      expect(a.currentRate, 5);
    });
  });

  // ── earned ─────────────────────────────────────────────────────────────────

  group('earned', () {
    final a = open()
        .applyEvent(
          ev(AccountEventType.interest, amount: 10, date: DateTime(2026, 3, 1)),
        )
        .applyEvent(
          ev(AccountEventType.interest, amount: 20, date: DateTime(2026, 8, 1)),
        )
        .applyEvent(
          ev(AccountEventType.deposit, amount: 5, date: DateTime(2026, 8, 2)),
        );

    test('sums interest only by default', () {
      expect(a.earned(), 30);
    });

    test('includeDeposits adds deposit events', () {
      expect(a.earned(includeDeposits: true), 35);
    });

    test('date bounds are from-inclusive, to-exclusive', () {
      expect(a.earned(from: DateTime(2026, 3, 1)), 30);
      expect(a.earned(to: DateTime(2026, 8, 1)), 10);
      expect(
        a.earned(from: DateTime(2026, 7, 1), to: DateTime(2026, 9, 1)),
        20,
      );
    });
  });

  // ── lastEventDate ──────────────────────────────────────────────────────────

  group('lastEventDate', () {
    test('is the most recent event date regardless of order', () {
      final a = open()
          .applyEvent(
            ev(
              AccountEventType.interest,
              amount: 10,
              date: DateTime(2026, 5, 1),
            ),
          )
          .applyEvent(
            ev(
              AccountEventType.interest,
              amount: 10,
              date: DateTime(2026, 3, 1),
            ),
          );
      expect(a.lastEventDate, DateTime(2026, 5, 1));
    });

    test('is null with no history', () {
      expect(Account(name: 'Empty').lastEventDate, isNull);
    });
  });

  // ── interestFYStr ──────────────────────────────────────────────────────────

  group('interestFYStr', () {
    test('formats FY interest with thousands separators', () {
      final a = open().applyEvent(
        AccountEvent(
          date: DateTime.now(),
          type: AccountEventType.interest,
          amount: 1234.5,
        ),
      );
      expect(a.interestFYStr, '\$1,234.50');
    });
  });

  // ── fyStart ────────────────────────────────────────────────────────────────

  group('fyStart', () {
    test('July onwards is the current year', () {
      expect(Account.fyStart(DateTime(2026, 7, 27)), DateTime(2026, 7, 1));
      expect(Account.fyStart(DateTime(2026, 12, 31)), DateTime(2026, 7, 1));
    });

    test('before July is the previous year', () {
      expect(Account.fyStart(DateTime(2026, 6, 30)), DateTime(2025, 7, 1));
      expect(Account.fyStart(DateTime(2026, 1, 1)), DateTime(2025, 7, 1));
    });
  });

  // ── rebuilt ────────────────────────────────────────────────────────────────

  group('rebuilt', () {
    Account sample() => open(rate: 4.0)
        .applyEvent(
          ev(AccountEventType.interest, amount: 10, date: DateTime(2026, 2, 1)),
        )
        .applyEvent(
          ev(
            AccountEventType.rateChange,
            rate: 4.5,
            date: DateTime(2026, 3, 1),
          ),
        )
        .applyEvent(
          ev(AccountEventType.interest, amount: 20, date: DateTime(2026, 4, 1)),
        );

    test('editing an amount recomputes balances downstream', () {
      final a = sample();
      final edited = a.events[1].copyWith(amount: 100.0);
      final b = a.rebuilt([
        for (final e in a.events)
          if (e.id == edited.id) edited else e,
      ]);
      expect(b.currentBalance, 1120);
      // The later interest event's running balance reflects the edit.
      expect(b.events.last.balance, 1120);
      expect(b.events[1].balance, 1100);
    });

    test('deleting an event recomputes balance and rate', () {
      final a = sample();
      final rateId = a.events[2].id;
      final b = a.rebuilt(a.events.where((e) => e.id != rateId).toList());
      expect(b.currentRate, 4.0);
      expect(b.currentBalance, 1030);
      expect(b.events, hasLength(3));
    });

    test('changing a date reorders the replay and previous fields', () {
      final a = open(rate: 4.0)
          .applyEvent(
            ev(
              AccountEventType.rateChange,
              rate: 5.0,
              date: DateTime(2026, 2, 1),
            ),
          )
          .applyEvent(
            ev(
              AccountEventType.rateChange,
              rate: 6.0,
              date: DateTime(2026, 3, 1),
            ),
          );
      // Move the 5.0% change after the 6.0% change.
      final moved = a.events[1].copyWith(date: DateTime(2026, 4, 1));
      final b = a.rebuilt([
        for (final e in a.events)
          if (e.id == moved.id) moved else e,
      ]);
      expect(b.currentRate, 5.0);
      final last = b.events.last;
      expect(last.rate, 5.0);
      expect(last.previous, 6.0);
    });

    test('changing an event type reapplies its semantics', () {
      final a = sample();
      // Reinterpret the 10 interest as a balance update to 10.
      final edited = a.events[1].copyWith(type: AccountEventType.balanceUpdate);
      final b = a.rebuilt([
        for (final e in a.events)
          if (e.id == edited.id) edited else e,
      ]);
      expect(b.currentBalance, 30);
      expect(b.events[1].previous, 1000);
    });

    test('same-date events keep their given order', () {
      final d = DateTime(2026, 2, 1);
      final a = open()
          .applyEvent(ev(AccountEventType.rateChange, rate: 4.5, date: d))
          .applyEvent(ev(AccountEventType.rateChange, rate: 4.8, date: d));
      final b = a.rebuilt(a.events);
      expect(b.currentRate, 4.8);
      expect(b.events.last.previous, 4.5);
    });

    test('interest sums are preserved through a rebuild', () {
      final a = sample();
      final b = a.rebuilt(a.events);
      expect(b.earned(), a.earned());
      expect(b.currentBalance, a.currentBalance);
      expect(b.currentRate, a.currentRate);
    });
  });

  // ── Currency ───────────────────────────────────────────────────────────────

  group('currency', () {
    test('defaults to AUD and displays with plain \$', () {
      final a = open();
      expect(a.currency, 'AUD');
      expect(a.balanceStr, '\$1,000.00');
    });

    test('foreign currency displays with its symbol', () {
      final a = Account.open(
        name: 'US Saver',
        currency: 'USD',
        openingBalance: 1000,
        date: DateTime(2026, 1, 1),
      );
      expect(a.balanceStr, 'US\$1,000.00');
      expect(a.interestFYStr, startsWith('US\$'));
    });

    test('round-trips through JSON', () {
      final a = Account.open(
        name: 'SG Saver',
        currency: 'SGD',
        openingBalance: 10,
        date: DateTime(2026, 1, 1),
      );
      expect(Account.fromJson(a.toJson()).currency, 'SGD');
    });

    test('legacy data without a currency loads as AUD', () {
      final j = open().toJson()..remove('currency');
      expect(Account.fromJson(j).currency, 'AUD');
    });
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  group('serialisation', () {
    test('account round-trips through JSON with its events', () {
      final a = open()
          .applyEvent(
            ev(AccountEventType.rateChange, rate: 4.6, note: 'RBA cut'),
          )
          .copyWith(number: '062-000 1234 5678', isClosed: true);
      final b = Account.fromJson(a.toJson());
      expect(b.id, a.id);
      expect(b.name, a.name);
      expect(b.institution, a.institution);
      expect(b.type, a.type);
      expect(b.number, a.number);
      expect(b.currentBalance, a.currentBalance);
      expect(b.currentRate, a.currentRate);
      expect(b.isClosed, isTrue);
      expect(b.events, hasLength(2));
      expect(b.events.last.previous, 4.0);
      expect(b.events.last.note, 'RBA cut');
      expect(b.events.last.date, a.events.last.date);
    });

    test('legacy income type name loads as deposit', () {
      final e = AccountEvent(
        date: DateTime(2026, 2, 1),
        type: AccountEventType.deposit,
        amount: 50,
      );
      final j = e.toJson();
      j['type'] = 'income';
      expect(AccountEvent.fromJson(j).type, AccountEventType.deposit);
    });

    test('unknown enum names fall back safely', () {
      final j = open().toJson();
      j['type'] = 'no-such-type';
      expect(Account.fromJson(j).type, AccountType.other);
    });
  });

  // ── Bonus interest ─────────────────────────────────────────────────────────

  group('bonus interest', () {
    test('base and bonus both add to the balance', () {
      final a = open().applyEvent(ev(AccountEventType.interest, amount: 10));
      final b = open().applyEvent(
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 10,
          bonus: 5,
        ),
      );
      expect(a.currentBalance, 1010);
      expect(b.currentBalance, 1015);
      expect(b.events.last.balance, 1015);
    });

    test('earned sums base plus bonus', () {
      final a = open().applyEvent(
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 10,
          bonus: 5,
        ),
      );
      expect(a.earned(), 15);
    });

    test('bonus round-trips through JSON', () {
      final e = AccountEvent(
        date: DateTime(2026, 2, 1),
        type: AccountEventType.interest,
        amount: 10,
        bonus: 5,
      );
      final back = AccountEvent.fromJson(e.toJson());
      expect(back.bonus, 5);
      expect(back.totalAmount, 15);
    });

    test('bonus survives a rebuild', () {
      final a = open().applyEvent(
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 10,
          bonus: 5,
        ),
      );
      final b = a.rebuilt(a.events);
      expect(b.currentBalance, 1015);
      expect(b.events.last.bonus, 5);
    });

    test('description shows total with base + bonus breakdown', () {
      final withBonus = AccountEvent(
        date: DateTime(2026, 2, 1),
        type: AccountEventType.interest,
        amount: 10,
        bonus: 5.5,
      );
      expect(withBonus.description, 'Interest \$15.50 (\$10.00 + \$5.50)');
      // No bonus keeps the plain form.
      expect(
        ev(AccountEventType.interest, amount: 12.3).description,
        'Interest \$12.30',
      );
    });
  });

  // ── Descriptions ───────────────────────────────────────────────────────────

  group('description', () {
    test('rate change shows old and new rate', () {
      final a = open().applyEvent(ev(AccountEventType.rateChange, rate: 4.35));
      expect(a.events.last.description, 'Rate 4.00% → 4.35%');
    });

    test('balance update shows old and new balance', () {
      final a = open().applyEvent(
        ev(AccountEventType.balanceUpdate, amount: 1234.56),
      );
      expect(a.events.last.description, 'Balance \$1,000.00 → \$1,234.56');
    });

    test('interest shows amount', () {
      expect(
        ev(AccountEventType.interest, amount: 12.3).description,
        'Interest \$12.30',
      );
    });
  });
}
