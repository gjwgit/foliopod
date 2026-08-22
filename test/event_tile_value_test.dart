/// Widget tests for the holding value shown on a history entry: the
/// units held times the price the entry records.
///
// Run: flutter test test/event_tile_value_test.dart

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/widgets/event_tile.dart';

void main() {
  final date = DateTime(2026, 8, 20);

  Future<void> pumpTile(
    WidgetTester tester,
    AccountEvent event, {
    String currency = 'USD',
    String? ticker,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          child: EventTile(event: event, currency: currency, ticker: ticker),
        ),
      ),
    ),
  );

  testWidgets('a price entry shows units, value and date', (tester) async {
    await pumpTile(
      tester,
      AccountEvent(
        date: date,
        type: AccountEventType.priceUpdate,
        price: 412.5,
        previous: 300,
        balance: 100,
      ),
      ticker: 'MSFT',
    );

    // The new price, without the one it replaces.
    expect(find.text('Price US\$412.50'), findsOneWidget);
    expect(find.text('Held 100'), findsOneWidget);
    expect(find.text('US\$41,250.00'), findsOneWidget);
  });

  testWidgets('a trade values the holding at its price', (tester) async {
    await pumpTile(
      tester,
      AccountEvent(
        date: date,
        type: AccountEventType.buy,
        amount: 50,
        price: 420,
        balance: 150,
      ),
      ticker: 'MSFT',
    );

    expect(find.text('US\$63,000.00'), findsOneWidget);
  });

  testWidgets('the figures line up between entries', (tester) async {
    // A dividend carries no price, so its value column is empty — the
    // date must still sit in the same column as the price entry's.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: Column(
              children: [
                EventTile(
                  event: AccountEvent(
                    date: date,
                    type: AccountEventType.priceUpdate,
                    price: 412.5,
                    balance: 100,
                  ),
                  currency: 'USD',
                  ticker: 'MSFT',
                ),
                EventTile(
                  event: AccountEvent(
                    date: DateTime(2026, 7, 3),
                    type: AccountEventType.dividend,
                    amount: 75,
                    balance: 100,
                  ),
                  currency: 'USD',
                  ticker: 'MSFT',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final first = tester.getTopLeft(find.text('20 Aug 2026')).dx;
    final second = tester.getTopLeft(find.text('3 Jul 2026')).dx;
    expect(first, second);
  });

  testWidgets('a cash entry shows no holding value', (tester) async {
    await pumpTile(
      tester,
      AccountEvent(
        date: date,
        type: AccountEventType.deposit,
        amount: 500,
        balance: 1500,
      ),
      currency: 'AUD',
    );

    expect(find.text('Bal \$1,500.00'), findsOneWidget);
    expect(find.text('\$500.00'), findsNothing);
  });
}
