/// Widget tests for the leading icon on an account tile: each kind of
/// account is meant to read at a glance, so the mapping is pinned here.
///
// Run: flutter test test/account_tile_icon_test.dart

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/widgets/account_tile.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, Account account) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: AccountTile(
              account: account,
              onTap: () {},
              onRecord: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
  }

  Account of(AccountType type, {bool closed = false}) => Account.open(
    name: 'Test',
    type: type,
    symbol: type == AccountType.shares ? 'MSFT' : null,
    openingBalance: 100,
    date: DateTime(2026, 1, 1),
  ).copyWith(isClosed: closed);

  final expected = {
    AccountType.savings: Icons.savings_outlined,
    AccountType.transaction: Icons.swap_horiz,
    AccountType.termDeposit: Icons.schedule,
    AccountType.offset: Icons.home_outlined,
    AccountType.shares: Icons.show_chart,
    AccountType.superannuation: Icons.beach_access,
    AccountType.other: Icons.account_balance,
  };

  group('leading icon', () {
    for (final entry in expected.entries) {
      testWidgets('${entry.key.label} shows its own icon', (tester) async {
        await pumpTile(tester, of(entry.key));
        expect(find.byIcon(entry.value), findsOneWidget);
      });
    }

    test('every account type has an icon assigned', () {
      // A new AccountType must be given an icon rather than falling
      // through to a default.
      expect(expected.keys.toSet(), AccountType.values.toSet());
    });

    testWidgets('savings and transaction are not the same icon', (
      tester,
    ) async {
      expect(
        expected[AccountType.savings],
        isNot(expected[AccountType.transaction]),
      );
      await pumpTile(tester, of(AccountType.transaction));
      expect(find.byIcon(Icons.savings_outlined), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    });

    testWidgets('a closed account shows a padlock instead', (tester) async {
      await pumpTile(tester, of(AccountType.savings, closed: true));
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.savings_outlined), findsNothing);
    });
  });
}
