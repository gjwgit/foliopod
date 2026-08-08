/// AccountHistory — an account's transaction log in a popup.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:foliopod/constants/app.dart' show baseCurrency;
import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/account_edit.dart';
import 'package:foliopod/pages/event_edit.dart';
import 'package:foliopod/pages/record_event.dart';
import 'package:foliopod/services/app_provider.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/money_format.dart';
import 'package:foliopod/services/portfolio_service.dart';
import 'package:foliopod/widgets/error_dialog.dart';
import 'package:foliopod/widgets/event_tile.dart';

/// Dialog showing every history entry for one account, most recent
/// first. Tap an entry to edit or delete it; the account's balance and
/// rate are recomputed by replaying the history. The header offers
/// recording a new entry and editing the account's details.
///
/// Watches the provider by [accountId] so the log refreshes in place as
/// entries are recorded, edited or deleted.
class AccountHistory extends StatelessWidget {
  final String accountId;
  const AccountHistory({super.key, required this.accountId});

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _record(BuildContext context, Account account) async {
    final provider = context.read<AppProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordEvent(
        account: account,
        onSave: (events) async {
          for (final event in events) {
            provider.recordEvent(account.id, event);
          }
          // Throws on failure so RecordEvent can report it and stay open.
          await savePodOrThrow(provider);
        },
      ),
    );
  }

  Future<void> _editAccount(BuildContext context, Account account) async {
    final provider = context.read<AppProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountEdit(
        account: account,
        onSave: (updated) async {
          provider.updateAccount(updated);
          // Throws on failure so AccountEdit can report it and stay open.
          await savePodOrThrow(provider);
        },
      ),
    );
  }

  Future<void> _editEvent(
    BuildContext context,
    Account account,
    AccountEvent event,
  ) async {
    final provider = context.read<AppProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EventEdit(
        event: event,
        account: account,
        onSave: (updated) async {
          provider.updateEvent(account.id, updated);
          // Throws on failure so EventEdit can report it and stay open.
          await savePodOrThrow(provider);
        },
        onDelete: () async {
          provider.deleteEvent(account.id, event.id);
          if (!context.mounted) return;
          await savePodOrError(context, provider);
        },
      ),
    );
  }

  /// Normalised-to-AUD note for foreign-currency accounts, e.g.
  /// ` (≈ A\$1,900.00)`, or empty for AUD accounts or when no rate is
  /// available. 20260729 gjw
  String _audNote(Account account) {
    // A shareholding is quoted in units, so always show its AUD market
    // value; a cash account only needs one when it is not already AUD.
    if (!account.isShares && account.currency == baseCurrency) return '';
    final aud = PortfolioService.audValue(account);
    if (aud == null) return '';
    final rate = ExchangeService.rateFromAud(account.currency);
    final rateNote = rate != null && account.currency != baseCurrency
        ? ', A\$1 = ${currencySymbol(account.currency)}'
              '${rate.toStringAsFixed(4)}'
        : '';
    return ' (≈ A\$${formatMoney(aud)}$rateNote)';
  }

  /// The middle clause of the subheading: the market price for a
  /// shareholding, or the interest rate for a cash account. 20260729 gjw
  String _rateOrPrice(Account account) {
    // A super fund has no headline rate to quote.
    if (account.isSuper && account.currentRate == 0) return '';
    if (!account.isShares) return 'at ${account.rateStr}';
    final price = PortfolioService.priceFor(account);
    return price != null
        ? 'at ${formatCurrencyAmount(price, account.currency)} each'
        : 'with no price yet';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  /// The subheading above the log: what is held, what it is worth, the
  /// rate or price where there is one, and the income so far this
  /// financial year. 20260731 gjw
  String _summary(Account account) {
    final middle = _rateOrPrice(account);
    return 'Currently ${account.holdingStr}${_audNote(account)}'
        '${middle.isEmpty ? '' : ' $middle'} — '
        '${account.interestFYStr} ${account.incomeLabel} since 1 July. '
        'Tap an entry to edit it.';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final account = provider.allAccounts
        .where((a) => a.id == accountId)
        .firstOrNull;
    if (account == null) return const SizedBox.shrink();

    final events = account.events.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(account.name, overflow: TextOverflow.ellipsis)),
          MarkdownTooltip(
            message: '''

**Record**

Record interest credited, a deposit, an interest rate change, or a
balance update for this account.

''',
            child: IconButton(
              icon: const Icon(Icons.add_card_outlined, size: 20),
              onPressed: () => _record(context, account),
            ),
          ),
          MarkdownTooltip(
            message: '''

**Edit account**

Edit the account's details — name, institution, type, number and
note.

''',
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editAccount(context, account),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SelectableText so the balance, rate and normalised value
            // can be copied; it carries its own selection handling, no
            // SelectionArea required. 20260729 gjw
            SelectableText(
              _summary(account),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const Divider(),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'No history yet.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, i) => EventTile(
                        event: events[i],
                        currency: account.currency,
                        ticker: account.symbol,
                        onTap: () => _editEvent(context, account, events[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
