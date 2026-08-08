/// AccountAmountsRow — the balance/price/rate row of the account editor.
///
/// The three figures are only editable while the account is new. Once it
/// exists they change through recorded events so the history stays a
/// complete record, and the fields explain that in their help.
///
// Time-stamp: <2026-08-08>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

/// The balance alongside the share price or the interest rate.
class AccountAmountsRow extends StatelessWidget {
  final TextEditingController balance;
  final TextEditingController price;
  final TextEditingController rate;

  /// Whether the account is being added rather than edited, which is the
  /// only time these figures can be typed in directly.
  final bool isNew;

  final bool isShares;
  final bool isSuper;

  const AccountAmountsRow({
    super.key,
    required this.balance,
    required this.price,
    required this.rate,
    required this.isNew,
    required this.isShares,
    required this.isSuper,
  });

  String get _balanceHelp => isNew
      ? '''

**Opening balance**

The opening balance of the account — for a superannuation fund, the
balance on your latest statement — recorded as the first history
entry.

'''
      : '''

**Balance**

The current balance changes only through recorded events so the
history stays complete. Use the Record button on the account to
update it.

''';

  String get _priceHelp => isNew
      ? '''

**Opening price**

The share price to start from, recorded as part of the opening entry.
It values the holding until a market price is fetched, so it is worth
setting when working offline.

'''
      : '''

**Share price**

The price the holding is currently marked at. It changes through
recorded Price Update entries — once a day when the fetched price has
moved, or by hand from the Record button — so the history keeps the
price series.

''';

  String get _rateHelp => isNew
      ? '''

**Interest rate**

The current interest rate of the account (% per annum).

'''
      : '''

**Interest rate**

The rate changes only through recorded events so the history stays
complete. Use the Record button on the account to record a rate
change.

''';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MarkdownTooltip(
            message: _balanceHelp,
            child: TextFormField(
              controller: balance,
              enabled: isNew,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: isShares
                    ? (isNew ? 'Units held' : 'Units')
                    : (isNew ? 'Opening balance' : 'Balance'),
                prefixText: isShares ? null : '\$ ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
        // A super fund has no headline rate, so the balance
        // takes the full width. 20260731 gjw
        if (!isSuper) ...[
          const Gap(12),
          Expanded(
            child: isShares
                ? MarkdownTooltip(
                    message: _priceHelp,
                    child: TextFormField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: isNew,
                      decoration: InputDecoration(
                        labelText: isNew ? 'Opening price' : 'Share price',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  )
                : MarkdownTooltip(
                    message: _rateHelp,
                    child: TextFormField(
                      controller: rate,
                      enabled: isNew,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rate % p.a.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
