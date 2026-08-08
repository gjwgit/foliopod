/// HistoryScreen — every recorded change across all accounts.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/event_edit.dart';
import 'package:foliopod/services/app_provider.dart';
import 'package:foliopod/widgets/error_dialog.dart';
import 'package:foliopod/widgets/event_tile.dart';
import 'package:foliopod/widgets/startup_overlay.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Edit or delete a history entry; the account's balance and rate are
  /// recomputed by replaying its history. 20260727 gjw
  Future<void> _editEvent(Account account, AccountEvent event) async {
    final provider = context.read<AppProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EventEdit(
        event: event,
        account: account,
        onSave: (updated) async {
          provider.updateEvent(account.id, updated);
          if (!mounted) return;
          await savePodOrError(context, provider);
        },
        onDelete: () async {
          provider.deleteEvent(account.id, event.id);
          if (!mounted) return;
          await savePodOrError(context, provider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;

    if (provider.busy) {
      return StartupOverlay(
        phase: provider.startupPhase,
        child: const SizedBox.expand(),
      );
    }

    var entries = provider.history;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      entries = entries
          .where(
            (h) =>
                h.account.name.toLowerCase().contains(q) ||
                h.event.type.label.toLowerCase().contains(q) ||
                h.event.description.toLowerCase().contains(q) ||
                (h.event.note?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search history…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const Gap(4),
              const MarkdownTooltip(
                message: '''

**History**

Every recorded change, most recent first: interest and deposits
credited, rate changes (with the old rate), balance updates (with the
old balance), and account openings. Tap an entry to edit or delete
it. Search matches account name, change type and notes.

''',
                child: Icon(Icons.help_outline, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? 'No history yet — record interest, deposits, '
                              'rate changes or balance updates on your '
                              'accounts.'
                        : 'No history matches your search.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => EventTile(
                    event: entries[i].event,
                    accountName: entries[i].account.name,
                    currency: entries[i].account.currency,
                    ticker: entries[i].account.symbol,
                    onTap: () =>
                        _editEvent(entries[i].account, entries[i].event),
                  ),
                ),
        ),
      ],
    );
  }
}
