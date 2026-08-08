/// Widget tests for the summary line under the accounts list.
///
// Run: flutter test test/account_total_bar_test.dart

library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/widgets/account_total_bar.dart';

void main() {
  tearDown(() => ExchangeService.setRatesForTesting(null));

  Future<void> pumpBar(WidgetTester tester, List<Account> accounts) async {
    // The bar is laid out at 900 below, wider than the default 800 test
    // surface, which would clip it into an overflow. 20260808 gjw
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: AccountTotalBar(accounts: accounts),
          ),
        ),
      ),
    );
  }

  Account of(
    AccountType type, {
    double balance = 10000,
    double rate = 4.8,
    String currency = 'AUD',
  }) => Account.open(
    name: 'Test',
    type: type,
    openingBalance: balance,
    rate: rate,
    currency: currency,
    date: DateTime(2026, 1, 1),
  );

  group('monthly total', () {
    testWidgets('sums the monthly estimate across accounts', (tester) async {
      // 10,000 at 4.8% is 40 a month, twice over.
      await pumpBar(tester, [
        of(AccountType.savings),
        of(AccountType.termDeposit),
      ]);
      expect(find.text('Monthly  \$80.00'), findsOneWidget);
    });

    testWidgets('leaves an offset account out of the total', (tester) async {
      await pumpBar(tester, [of(AccountType.savings), of(AccountType.offset)]);
      // Only the savings account contributes.
      expect(find.text('Monthly  \$40.00'), findsOneWidget);
    });

    testWidgets('is omitted when no account has a rate', (tester) async {
      await pumpBar(tester, [of(AccountType.transaction, rate: 0)]);
      expect(find.textContaining('Monthly'), findsNothing);
      expect(find.textContaining('Total'), findsOneWidget);
    });

    testWidgets('an offset alone leaves no monthly figure', (tester) async {
      await pumpBar(tester, [of(AccountType.offset)]);
      expect(find.textContaining('Monthly'), findsNothing);
    });

    testWidgets('foreign amounts are converted to AUD', (tester) async {
      // 1 AUD = 0.65 USD. US$1,300 at 12% earns US$13 a month = A$20.
      ExchangeService.setRatesForTesting({'USD': 0.65});
      await pumpBar(tester, [
        of(AccountType.savings, balance: 1300, rate: 12, currency: 'USD'),
      ]);
      expect(find.text('Monthly  A\$20.00'), findsOneWidget);
    });
  });
}
