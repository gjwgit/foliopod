/// AccountTile — a single account row in the list.
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
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:foliopod/constants/app.dart' show baseCurrency;
import 'package:foliopod/models/account.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/money_format.dart';
import 'package:foliopod/services/portfolio_service.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;
  final VoidCallback onRecord;
  final VoidCallback onDelete;

  const AccountTile({
    super.key,
    required this.account,
    required this.onTap,
    required this.onRecord,
    required this.onDelete,
  });

  /// Tooltip for the normalised AUD figure, covering a shareholding
  /// (units times market price) and a foreign cash account.
  String _audHelp(Account account, String rateNote, double? price) {
    if (account.isShares) {
      final priced = price != null
          ? 'the latest price of '
                '${formatCurrencyAmount(price, account.currency)}'
          : 'the latest price';
      return '''

**Market value in AUD**

The units held valued at $priced, converted to AUD at the ECB daily
reference rate (frankfurter.app)$rateNote. Shown as — until a price
and rate have been fetched.

''';
    }
    return '''

**Normalised to AUD**

The balance converted to AUD at the ECB daily reference rate
(frankfurter.app)$rateNote. Shown as — when no rate has been fetched
yet.

''';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final closed = account.isClosed;
    final last = account.lastEventDate;

    // Normalised value for foreign-currency accounts, when a rate is
    // available (ECB daily rates via ExchangeService). 20260729 gjw
    // A shareholding always shows its AUD value (it is units, not money,
    // in the main line); a foreign cash account shows one when converted.
    final showAud = account.isShares || account.currency != baseCurrency;
    final aud = showAud ? PortfolioService.audValue(account) : null;
    final price = PortfolioService.priceFor(account);
    final audRate = account.currency == baseCurrency
        ? null
        : ExchangeService.rateFromAud(account.currency);
    final rateNote = audRate != null
        ? ': A\$1 = ${currencySymbol(account.currency)}'
              '${audRate.toStringAsFixed(4)}'
        : '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  closed ? Icons.lock_outline : Icons.account_balance,
                  size: 20,
                  color: closed ? cs.onSurfaceVariant : cs.primary,
                ),
              ),
              const Gap(10),
              // Name, institution, note.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (closed) ...[
                          const Gap(8),
                          Text(
                            'Closed',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (account.institution != null &&
                        account.institution!.isNotEmpty)
                      Text(
                        '${account.institution} — ${account.type.label}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        account.type.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    if (last != null)
                      MarkdownTooltip(
                        message: '''

**Latest transaction**

The date of the most recent entry in this account's history — tap
the account to see the full transaction log.

''',
                        child: Text(
                          'Latest ${DateFormat('d MMM yyyy').format(last)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (account.note != null && account.note!.isNotEmpty)
                      Text(
                        account.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Gap(10),
              // Balance, rate, interest FY.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    account.holdingStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  if (showAud)
                    MarkdownTooltip(
                      message: _audHelp(account, rateNote, price),
                      child: Text(
                        aud != null ? '≈ A\$${formatMoney(aud)}' : '≈ A\$ —',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    account.isShares
                        ? (price != null
                              ? '@ ${formatCurrencyAmount(price, account.currency)}'
                              : '@ —')
                        : account.rateStr,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  MarkdownTooltip(
                    message: '''

**Income this FY**

Total earned since 1 July (the current financial year) — interest
including any bonus interest, or dividends for a shareholding.

''',
                    child: Text(
                      'FY ${account.interestFYStr}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              // Actions.
              MarkdownTooltip(
                message: '''

**Record**

Record interest credited, a deposit, an interest rate change, or a
balance update for this account. Each is kept as a dated history
entry.

''',
                child: IconButton(
                  icon: const Icon(Icons.add_card_outlined, size: 20),
                  onPressed: onRecord,
                ),
              ),
              MarkdownTooltip(
                message: '''

**Delete**

Delete this account and its entire history. Consider marking the
account as Closed instead to keep its history.

''',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
