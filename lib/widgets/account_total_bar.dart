/// AccountTotalBar — summed balance and interest for a list of accounts.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/portfolio_service.dart';

class AccountTotalBar extends StatelessWidget {
  final List<Account> accounts;

  const AccountTotalBar({super.key, required this.accounts});

  /// Tooltip text for the totals, reflecting whether any conversion to
  /// AUD was involved and which day's rates were used.
  String _totalsHelp(bool foreign, DateTime? ratesDate, int unconverted) {
    if (!foreign) {
      return '''

**Totals**

Totals across the listed accounts. Interest FY is the interest earned
since 1 July.

''';
    }
    final dated = ratesDate != null
        ? ' of ${ratesDate.toIso8601String().substring(0, 10)}'
        : '';
    final excluded = unconverted > 0
        ? 'Accounts awaiting rates are excluded from the totals. '
        : '';
    return '''

**Totals**

Totals across the listed accounts, normalised to AUD at the ECB daily
reference rates (frankfurter.app)$dated. ${excluded}Interest FY is
the interest earned since 1 July.

''';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');

    // Totals are normalised to AUD at the ECB daily reference rates.
    // Accounts whose currency has no rate available yet are excluded
    // from the sums and counted so the bar can say so. 20260729 gjw
    var balance = 0.0;
    var interestFY = 0.0;
    var unconverted = 0;
    for (final a in accounts) {
      final b = PortfolioService.audValue(a);
      final i = PortfolioService.audIncomeFY(a);
      if (b == null || i == null) {
        unconverted++;
      } else {
        balance += b;
        interestFY += i;
      }
    }
    final count = accounts.length;
    final plural = count == 1 ? 'account' : 'accounts';
    final ratesDate = ExchangeService.ratesDate;
    final foreign = accounts.any((a) => a.currency != 'AUD');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.surfaceContainerLow,
      child: Row(
        children: [
          Text(
            '$count $plural',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          if (unconverted > 0) ...[
            const SizedBox(width: 8),
            Text(
              '($unconverted awaiting prices/rates)',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
          const Spacer(),
          MarkdownTooltip(
            message: _totalsHelp(foreign, ratesDate, unconverted),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Interest FY  ${foreign ? 'A' : ''}'
                  '\$${fmt.format(interestFY)}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Text(
                  'Total  ${foreign ? 'A' : ''}\$${fmt.format(balance)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
