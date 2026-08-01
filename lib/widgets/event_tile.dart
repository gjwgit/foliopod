/// EventTile — a single history entry row.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import 'package:foliopod/constants/app.dart' show baseCurrency;
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/services/money_format.dart';

class EventTile extends StatelessWidget {
  final AccountEvent event;

  /// Name of the account the event belongs to. Shown when listing events
  /// across accounts; pass null in a single-account context.
  final String? accountName;

  /// Invoked when the entry is tapped (e.g. to open the event editor).
  final VoidCallback? onTap;

  /// ISO currency code of the owning account, for amount display.
  final String currency;

  /// Ticker of the owning account when it is a shareholding, so
  /// quantities show as units rather than money. 20260729 gjw
  final String? ticker;

  const EventTile({
    super.key,
    required this.event,
    this.accountName,
    this.onTap,
    this.currency = baseCurrency,
    this.ticker,
  });

  IconData get _icon => switch (event.type) {
    AccountEventType.created => Icons.fiber_new_outlined,
    AccountEventType.interest => Icons.savings_outlined,
    AccountEventType.deposit => Icons.attach_money,
    AccountEventType.rateChange => Icons.percent,
    AccountEventType.balanceUpdate => Icons.edit_outlined,
    AccountEventType.buy => Icons.add_shopping_cart,
    AccountEventType.sell => Icons.sell_outlined,
    AccountEventType.dividend => Icons.payments_outlined,
    AccountEventType.priceUpdate => Icons.show_chart,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('d MMM yyyy');

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(_icon, size: 20, color: cs.primary),
      title: Text(
        accountName != null
            ? '$accountName — ${event.describe(symbol: currencySymbol(currency), ticker: ticker)}'
            : event.describe(symbol: currencySymbol(currency), ticker: ticker),
      ),
      subtitle: event.note != null && event.note!.isNotEmpty
          ? Text(event.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (event.balance != null)
            Text(
              ticker != null
                  ? 'Held ${formatUnits(event.balance!)}'
                  : 'Bal ${formatCurrencyAmount(event.balance!, currency)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          const Gap(12),
          Text(
            dateFmt.format(event.date),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
