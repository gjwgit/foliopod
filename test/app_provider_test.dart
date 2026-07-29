/// Tests for AppProvider — CRUD, event recording, totals, history.
///
// Run: flutter test test/app_provider_test.dart

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/services/app_provider.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  AppProvider fresh([List<Account> accounts = const []]) {
    final p = AppProvider();
    p.loadTestData(accounts: accounts);
    return p;
  }

  Account make({
    String name = 'Saver',
    double balance = 1000,
    double rate = 4.0,
    DateTime? date,
  }) => Account.open(
    name: name,
    openingBalance: balance,
    rate: rate,
    date: date ?? DateTime(2026, 1, 1),
  );

  // ── CRUD ───────────────────────────────────────────────────────────────────

  group('CRUD', () {
    test('addAccount appears in allAccounts', () {
      final p = fresh();
      p.addAccount(make(name: 'Everyday'));
      expect(p.allAccounts, hasLength(1));
      expect(p.allAccounts.first.name, 'Everyday');
    });

    test('updateAccount replaces by id', () {
      final a = make();
      final p = fresh([a]);
      p.updateAccount(a.copyWith(name: 'Renamed'));
      expect(p.allAccounts.single.name, 'Renamed');
    });

    test('deleteAccount removes by id', () {
      final a = make();
      final p = fresh([a, make(name: 'Other')]);
      p.deleteAccount(a.id);
      expect(p.allAccounts.single.name, 'Other');
    });
  });

  // ── Open / closed split ────────────────────────────────────────────────────

  group('openAccounts', () {
    test('closed accounts are excluded and totals ignore them', () {
      final a = make(name: 'Open', balance: 100);
      final b = make(name: 'Gone', balance: 900).copyWith(isClosed: true);
      final p = fresh([a, b]);
      expect(p.openAccounts.map((x) => x.name), ['Open']);
      expect(p.closedAccounts.map((x) => x.name), ['Gone']);
      expect(p.totalBalance, 100);
    });

    test('sorted case-insensitively by name', () {
      final p = fresh([make(name: 'zeta'), make(name: 'Alpha')]);
      expect(p.openAccounts.map((x) => x.name), ['Alpha', 'zeta']);
    });
  });

  // ── recordEvent ────────────────────────────────────────────────────────────

  group('recordEvent', () {
    test('interest updates the account balance and appends history', () {
      final a = make();
      final p = fresh([a]);
      p.recordEvent(
        a.id,
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 25,
        ),
      );
      final updated = p.allAccounts.single;
      expect(updated.currentBalance, 1025);
      expect(updated.events, hasLength(2));
      expect(updated.events.last.balance, 1025);
    });

    test('rate change records the previous rate', () {
      final a = make(rate: 4.0);
      final p = fresh([a]);
      p.recordEvent(
        a.id,
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.rateChange,
          rate: 3.85,
        ),
      );
      final updated = p.allAccounts.single;
      expect(updated.currentRate, 3.85);
      expect(updated.events.last.previous, 4.0);
    });

    test('only the targeted account changes', () {
      final a = make(name: 'A');
      final b = make(name: 'B');
      final p = fresh([a, b]);
      p.recordEvent(
        a.id,
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 10,
        ),
      );
      expect(
        p.allAccounts.firstWhere((x) => x.id == b.id).currentBalance,
        1000,
      );
    });
  });

  // ── importAccounts ─────────────────────────────────────────────────────────

  group('importAccounts', () {
    test('adds new accounts and skips existing ids', () {
      final a = make(name: 'Existing');
      final b = make(name: 'New');
      final p = fresh([a]);
      final added = p.importAccounts([a, b]);
      expect(added, 1);
      expect(p.allAccounts, hasLength(2));
      expect(p.allAccounts.map((x) => x.name), contains('New'));
    });

    test('re-importing the same backup is a no-op', () {
      final a = make();
      final p = fresh([a]);
      expect(p.importAccounts([a]), 0);
      expect(p.allAccounts, hasLength(1));
    });

    test('imported accounts keep their histories', () {
      final a = make().applyEvent(
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 25,
          bonus: 5,
        ),
      );
      final p = fresh([]);
      p.importAccounts([Account.fromJson(a.toJson())]);
      final imported = p.allAccounts.single;
      expect(imported.events, hasLength(2));
      expect(imported.currentBalance, 1030);
      expect(imported.events.last.bonus, 5);
    });
  });

  // ── updateEvent / deleteEvent ──────────────────────────────────────────────

  group('updateEvent', () {
    test('edited amount recomputes the account balance', () {
      final a = make();
      final p = fresh([a]);
      p.recordEvent(
        a.id,
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 25,
        ),
      );
      final event = p.allAccounts.single.events.last;
      p.updateEvent(a.id, event.copyWith(amount: 75.0));
      final updated = p.allAccounts.single;
      expect(updated.currentBalance, 1075);
      expect(updated.events.last.balance, 1075);
    });
  });

  group('deleteEvent', () {
    test('removed entry recomputes balance from remaining history', () {
      final a = make();
      final p = fresh([a]);
      p.recordEvent(
        a.id,
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 25,
        ),
      );
      final id = p.allAccounts.single.events.last.id;
      p.deleteEvent(a.id, id);
      final updated = p.allAccounts.single;
      expect(updated.currentBalance, 1000);
      expect(updated.events, hasLength(1));
    });
  });

  // ── History ────────────────────────────────────────────────────────────────

  group('history', () {
    test('flattens events across accounts, most recent first', () {
      final a = make(name: 'A', date: DateTime(2026, 1, 1));
      final b = make(name: 'B', date: DateTime(2026, 3, 1));
      final p = fresh([a, b]);
      p.recordEvent(
        a.id,
        AccountEvent(
          date: DateTime(2026, 2, 1),
          type: AccountEventType.interest,
          amount: 10,
        ),
      );
      final dates = p.history.map((h) => h.event.date).toList();
      expect(dates, [
        DateTime(2026, 3, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 1, 1),
      ]);
      expect(p.history.first.account.name, 'B');
    });
  });
}
