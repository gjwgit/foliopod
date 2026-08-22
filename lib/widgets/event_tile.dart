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
    AccountEventType.contribution => Icons.input,
    AccountEventType.earnings => Icons.trending_up,
    AccountEventType.fee => Icons.money_off,
  };

  // 20260822 gjw Fixed column widths for the figures on the right, so
  // they line up down the list as a table rather than drifting with the
  // width of each entry's text.
  static const _heldWidth = 92.0;
  static const _valueWidth = 104.0;
  static const _dateWidth = 76.0;

  /// One right-aligned column of the trailing table. Digits are tabular
  /// so the decimal points align between rows, and an empty [text] holds
  /// the column open when an entry has nothing to show there.
  Widget _cell(String text, double width, Color colour) => SizedBox(
    width: width,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: colour,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('d MMM yyyy');

    // 20260822 gjw For a shareholding, what the holding was worth at this
    // entry: the units held after it times the price it records. Null
    // for a cash account, and for entries carrying no price.
    final value = ticker != null && event.price != null && event.balance != null
        ? event.price! * event.balance!
        : null;

    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(_icon, size: 20, color: cs.primary),
      title: Text(
        accountName != null
            ? '$accountName — ${event.describe(symbol: currencySymbol(currency), ticker: ticker)}'
            : event.describe(symbol: currencySymbol(currency), ticker: ticker),
        // One line per entry, so every row of the table is the same
        // height. 20260822 gjw
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: event.note != null && event.note!.isNotEmpty
          ? Text(event.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell(
            event.balance == null
                ? ''
                : ticker != null
                ? 'Held ${formatUnits(event.balance!)}'
                : 'Bal ${formatCurrencyAmount(event.balance!, currency)}',
            _heldWidth,
            cs.onSurfaceVariant,
          ),
          // The value column only exists for a shareholding, but is held
          // open on its entries that carry no price.
          if (ticker != null) ...[
            const Gap(8),
            _cell(
              value == null ? '' : formatCurrencyAmount(value, currency),
              _valueWidth,
              cs.onSurfaceVariant,
            ),
          ],
          const Gap(8),
          _cell(dateFmt.format(event.date), _dateWidth, cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
