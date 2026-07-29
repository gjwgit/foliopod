/// Widget tests for RecordEvent — bonus interest and "Balance after".
///
// Run: flutter test test/record_event_test.dart

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/record_event.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  Account account() => Account.open(
    name: 'Saver',
    openingBalance: 1000,
    rate: 4.0,
    date: DateTime(2026, 1, 1),
  );

  /// Pumps a host app with a button that opens the RecordEvent dialog and
  /// captures the popped result.
  Future<List<AccountEvent>? Function()> openDialog(WidgetTester tester) async {
    List<AccountEvent>? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await showDialog<List<AccountEvent>>(
                  context: context,
                  builder: (_) => RecordEvent(account: account()),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => popped;
  }

  final value = find.byKey(const ValueKey('value'));
  final bonus = find.byKey(const ValueKey('bonus'));
  final balance = find.byKey(const ValueKey('balance'));

  // ── Tests ──────────────────────────────────────────────────────────────────

  testWidgets('balance auto-fills from the amount', (tester) async {
    await openDialog(tester);
    await tester.enterText(value, '25');
    await tester.pump();
    expect(find.text('1,025.00'), findsOneWidget);
  });

  testWidgets('bonus interest is included in the auto-fill', (tester) async {
    await openDialog(tester);
    await tester.enterText(value, '10');
    await tester.pump();
    await tester.enterText(bonus, '5');
    await tester.pump();
    expect(find.text('1,015.00'), findsOneWidget);
  });

  testWidgets('base and bonus save as one entry', (tester) async {
    final popped = await openDialog(tester);
    await tester.enterText(value, '10');
    await tester.pump();
    await tester.enterText(bonus, '5');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final events = popped()!;
    expect(events, hasLength(1));
    expect(events.first.type, AccountEventType.interest);
    expect(events.first.amount, 10);
    expect(events.first.bonus, 5);
    expect(events.first.totalAmount, 15);
  });

  testWidgets('empty bonus saves as null', (tester) async {
    final popped = await openDialog(tester);
    await tester.enterText(value, '25');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final events = popped()!;
    expect(events, hasLength(1));
    expect(events.first.amount, 25);
    expect(events.first.bonus, isNull);
  });

  testWidgets('edited balance adds a balance-update entry', (tester) async {
    final popped = await openDialog(tester);
    await tester.enterText(value, '25');
    await tester.pump();
    // Commas in the typed number are accepted and stripped.
    await tester.enterText(balance, '1,500.00');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final events = popped()!;
    expect(events, hasLength(2));
    expect(events.first.type, AccountEventType.interest);
    expect(events.first.amount, 25);
    expect(events.last.type, AccountEventType.balanceUpdate);
    expect(events.last.amount, 1500);
    expect(events.last.note, 'Adjusted with Interest');
    expect(events.last.date, events.first.date);
  });

  testWidgets('auto-fill stops once the balance is edited', (tester) async {
    await openDialog(tester);
    await tester.enterText(value, '25');
    await tester.pump();
    await tester.enterText(balance, '1,500');
    await tester.pump();
    await tester.enterText(value, '50');
    await tester.pump();
    // The stated balance is preserved, not overwritten by the new amount.
    expect(find.text('1,500'), findsOneWidget);
    expect(find.text('1,050.00'), findsNothing);
  });
}
