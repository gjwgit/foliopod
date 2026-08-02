/// Widget tests for the figures in the middle of an account tile: the
/// change since 1 July and the monthly estimate beneath it.
///
// Run: flutter test test/account_tile_stats_test.dart

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/widgets/account_tile.dart';

void main() {
  /// Pumps a tile wide enough for the middle column to appear.
  Future<void> pumpTile(
    WidgetTester tester,
    Account account, {
    double width = 700,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
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

  Account of(AccountType type, {double rate = 4.8}) => Account.open(
    name: 'Test',
    type: type,
    symbol: type == AccountType.shares ? 'MSFT' : null,
    openingBalance: 10000,
    rate: rate,
    date: DateTime(2026, 1, 1),
  );

  group('monthly figure', () {
    testWidgets('a rate-bearing account labels it Monthly', (tester) async {
      await pumpTile(tester, of(AccountType.savings));
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Benefit'), findsNothing);
      // 10,000 at 4.8% is 480 a year, so 40 a month.
      expect(find.text('\$40.00'), findsOneWidget);
    });

    testWidgets('an offset account labels it Benefit', (tester) async {
      await pumpTile(tester, of(AccountType.offset));
      expect(find.text('Benefit'), findsOneWidget);
      expect(find.text('Monthly'), findsNothing);
    });

    testWidgets('no rate means no monthly line at all', (tester) async {
      await pumpTile(tester, of(AccountType.transaction, rate: 0));
      expect(find.text('Monthly'), findsNothing);
      expect(find.text('Benefit'), findsNothing);
      // The change since 1 July is still shown.
      expect(find.text('Since 1 Jul'), findsOneWidget);
    });

    testWidgets('the label drops the Est. prefix', (tester) async {
      await pumpTile(tester, of(AccountType.savings));
      expect(find.text('Est. Monthly'), findsNothing);
    });
  });

  group('narrow tiles', () {
    testWidgets('the middle column is dropped when there is no room', (
      tester,
    ) async {
      await pumpTile(tester, of(AccountType.savings), width: 400);
      expect(find.text('Since 1 Jul'), findsNothing);
      expect(find.text('Monthly'), findsNothing);
    });
  });
}
