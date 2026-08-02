/// RecordEvent — dialog to record a change against an account.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:emacs_text_field/emacs_text_field.dart';
import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/event_date_row.dart';
import 'package:foliopod/services/money_format.dart';

/// Dialog to record interest credited, a deposit, an interest rate
/// change, or a balance update against [account], on an editable date.
/// Interest
/// can be split into base and bonus interest (as banks credit them),
/// added together. 20260727 gjw
///
/// A "Balance after" field shows the balance the entry will produce and
/// can be edited to match the bank (e.g. when untracked transactions have
/// moved the balance): if it differs from the computed result, a second
/// balance-update entry is recorded alongside, so the history remains an
/// honest record of what was credited versus what was stated. 20260727 gjw
///
/// Pops the `List<AccountEvent>` to record (one or two entries) on Save,
/// or null on Cancel. The caller applies them in order via
/// AppProvider.recordEvent.
class RecordEvent extends StatefulWidget {
  final Account account;
  const RecordEvent({super.key, required this.account});

  @override
  State<RecordEvent> createState() => _RecordEventState();
}

class _RecordEventState extends State<RecordEvent> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _bonus = TextEditingController();
  final _price = TextEditingController();
  late final TextEditingController _balance;
  final _note = TextEditingController();
  late AccountEventType _type;
  DateTime _date = DateTime.now();

  /// True once the user has edited the balance field themselves, after
  /// which it is no longer auto-filled from the amount.
  bool _balanceTouched = false;

  /// Guards the balance listener while the field is auto-filled.
  bool _syncing = false;

  /// The recordable event types for this account (created is only ever
  /// added by Account.open). A shareholding trades units and receives
  /// dividends; a cash account earns interest and takes deposits.
  /// 20260729 gjw
  List<AccountEventType> get _types => widget.account.isShares
      ? const [
          AccountEventType.buy,
          AccountEventType.sell,
          AccountEventType.dividend,
          AccountEventType.priceUpdate,
          AccountEventType.balanceUpdate,
        ]
      : _superFund
      ? const [
          AccountEventType.contribution,
          AccountEventType.earnings,
          AccountEventType.fee,
          AccountEventType.balanceUpdate,
        ]
      : const [
          AccountEventType.interest,
          AccountEventType.deposit,
          AccountEventType.fee,
          AccountEventType.rateChange,
          AccountEventType.balanceUpdate,
        ];

  bool get _isRate => _type == AccountEventType.rateChange;

  /// A newly observed share price: the value entered is the price, the
  /// shareholding counterpart of a rate change. 20260730 gjw
  bool get _isPriceUpdate => _type == AccountEventType.priceUpdate;

  bool get _isInterest => _type == AccountEventType.interest;

  bool get _isBalanceUpdate => _type == AccountEventType.balanceUpdate;

  /// A buy or sell: the value entered is a quantity of units, and a
  /// per-unit price can be recorded alongside.
  bool get _isTrade =>
      _type == AccountEventType.buy || _type == AccountEventType.sell;

  /// Whether the value field holds units rather than money.
  bool get _isUnits => _isTrade || (_isBalanceUpdate && _shares);

  bool get _shares => widget.account.isShares;

  bool get _superFund => widget.account.isSuper;

  /// Prefix for a money field in the account's currency; null for a
  /// units or rate field.
  String? get _moneyPrefix => '${currencySymbol(widget.account.currency)} ';

  static const _superTypeHelp = '''

**What to record**

- **Contribution** — money paid into the fund by you or your
  employer; added to the balance.
- **Earnings** — the investment return credited by the fund. Enter a
  negative amount for a loss. Counts as income earned.
- **Fee** — an administration, investment or insurance charge
  deducted from the balance.
- **Balance Update** — set the balance to match your fund statement;
  the old balance is kept in the history.

''';

  static const _cashTypeHelp = '''

**What to record**

- **Interest** — interest credited by the bank; added to the balance.
- **Deposit** — money deposited into the account; added to the
  balance.
- **Fee** — an account or transaction charge; deducted from the
  balance.
- **Rate Change** — the bank changed the interest rate; the old rate is
  kept in the history.
- **Balance Update** — set the balance to match the bank; the old
  balance is kept in the history.

''';

  static const _sharesTypeHelp = '''

**What to record**

- **Buy** — units acquired; added to the holding, with the price paid
  recorded for the history.
- **Sell** — units disposed of; subtracted from the holding.
- **Dividend** — cash dividend received; counts as income earned and
  leaves the units unchanged.
- **Price Update** — a newly observed share price; the old price is
  kept in the history. One is recorded automatically each day the
  fetched price has moved.
- **Balance Update** — set the units held to match your broker; the
  old figure is kept in the history.

''';

  /// The dropdown's guidance, matching the kind of account.
  String get _typeHelp {
    if (_shares) return _sharesTypeHelp;
    return _superFund ? _superTypeHelp : _cashTypeHelp;
  }

  String get _valueLabel => switch (_type) {
    AccountEventType.interest => 'Base interest',
    AccountEventType.deposit => 'Amount deposited',
    AccountEventType.rateChange => 'New rate % p.a.',
    AccountEventType.buy => 'Units bought',
    AccountEventType.sell => 'Units sold',
    AccountEventType.dividend => 'Dividend received',
    AccountEventType.priceUpdate => 'New share price',
    AccountEventType.contribution => 'Contribution',
    AccountEventType.earnings => 'Earnings (negative for a loss)',
    AccountEventType.fee => 'Fee charged',
    _ => _shares ? 'Units held' : 'New balance',
  };

  /// The balance the primary entry alone would produce (for interest,
  /// base plus any bonus).
  double get _computedBalance {
    final v = parseNum(_value.text) ?? 0;
    final b = _isInterest ? (parseNum(_bonus.text) ?? 0) : 0.0;
    return switch (_type) {
      AccountEventType.interest ||
      AccountEventType.deposit => widget.account.currentBalance + v + b,
      AccountEventType.buy => widget.account.currentBalance + v,
      AccountEventType.sell => widget.account.currentBalance - v,
      AccountEventType.contribution ||
      AccountEventType.earnings => widget.account.currentBalance + v,
      AccountEventType.fee => widget.account.currentBalance - v,
      // A dividend is cash paid out: the units held do not change.
      _ => widget.account.currentBalance,
    };
  }

  @override
  void initState() {
    super.initState();
    _type = _types.first;
    _balance = TextEditingController(
      text: _shares
          ? formatUnits(widget.account.currentBalance)
          : formatMoney(widget.account.currentBalance),
    );
    _price.addListener(() => setState(() {}));
    _value.addListener(() {
      _syncBalance();
      setState(() {});
    });
    _bonus.addListener(() {
      _syncBalance();
      setState(() {});
    });
    _balance.addListener(() {
      if (!_syncing) _balanceTouched = true;
      setState(() {});
    });
  }

  /// Auto-fill the balance field from the amount until the user edits it.
  void _syncBalance() {
    if (_balanceTouched || _isBalanceUpdate) return;
    _syncing = true;
    _balance.text = _shares
        ? formatUnits(_computedBalance)
        : formatMoney(_computedBalance);
    _syncing = false;
  }

  @override
  void dispose() {
    _value.dispose();
    _bonus.dispose();
    _price.dispose();
    _balance.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid =>
      parseNum(_value.text) != null &&
      (_isBalanceUpdate || parseNum(_balance.text) != null) &&
      (!_isInterest ||
          _bonus.text.trim().isEmpty ||
          parseNum(_bonus.text) != null) &&
      (!_isTrade ||
          _price.text.trim().isEmpty ||
          parseNum(_price.text) != null);

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final v = parseNum(_value.text)!;
    final bonus = _isInterest && _bonus.text.trim().isNotEmpty
        ? parseNum(_bonus.text)
        : null;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final events = <AccountEvent>[
      AccountEvent(
        date: _date,
        type: _type,
        price: _isPriceUpdate
            ? v
            : (_isTrade && _price.text.trim().isNotEmpty
                  ? parseNum(_price.text)
                  : null),
        amount: _isRate || _isPriceUpdate ? null : v,
        bonus: bonus,
        rate: _isRate ? v : null,
        note: note,
      ),
    ];
    // A stated balance differing from the computed result is recorded as
    // its own balance-update entry so the history stays complete.
    if (!_isBalanceUpdate) {
      final stated = parseNum(_balance.text)!;
      if ((stated - _computedBalance).abs() >= 0.005) {
        events.add(
          AccountEvent(
            date: _date,
            type: AccountEventType.balanceUpdate,
            amount: stated,
            note: 'Adjusted with ${_type.label}',
          ),
        );
      }
    }
    Navigator.of(context).pop(events);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = widget.account;

    return AlertDialog(
      title: Text('Record — ${a.name}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current values for reference while recording.
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Currently ${a.balanceStr} at ${a.rateStr}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
              const Gap(12),
              MarkdownTooltip(
                message: _typeHelp,
                child: DropdownButtonFormField<AccountEventType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Record',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final t in _types)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) {
                    setState(() => _type = v!);
                    _syncBalance();
                  },
                ),
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('value'),
                      controller: _value,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _valueLabel,
                        prefixText: _isRate || _isUnits ? null : _moneyPrefix,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) =>
                          parseNum(v ?? '') == null ? 'Number' : null,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: EventDateRow(
                      label: 'Date',
                      value: _date,
                      onChanged: (d) => setState(() => _date = d),
                    ),
                  ),
                ],
              ),
              if (_isTrade) ...[
                const Gap(12),
                MarkdownTooltip(
                  message: '''

**Price paid**

The per-unit price for this trade, recorded for the history. Optional
— the holding is always valued at the latest market price, not this
one. Leave empty if you would rather not record it.

''',
                  child: TextFormField(
                    key: const ValueKey('price'),
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Price each',
                      prefixText: _moneyPrefix,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty || parseNum(v) != null)
                        ? null
                        : 'Number',
                  ),
                ),
              ],
              if (_isInterest) ...[
                const Gap(12),
                MarkdownTooltip(
                  message: '''

**Bonus interest**

Bonus interest credited together with the base interest — for
example when the account's bonus rate conditions were met. The base
and bonus are added together in the balance and interest totals.
Leave empty when there is no bonus.

''',
                  child: TextFormField(
                    key: const ValueKey('bonus'),
                    controller: _bonus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Bonus interest',
                      prefixText: _moneyPrefix,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty || parseNum(v) != null)
                        ? null
                        : 'Number',
                  ),
                ),
              ],
              if (!_isBalanceUpdate) ...[
                const Gap(12),
                MarkdownTooltip(
                  message:
                      '''

${_shares ? '**Units after**' : '**Balance after**'}

The ${_shares ? 'holding' : 'balance'} this entry will produce, filled in
automatically from the amount. Edit it to match your ${_shares ? 'broker' : 'bank'} if untracked
transactions have moved it — the difference is recorded as a separate
balance update alongside this entry, keeping the history complete.

''',
                  child: TextFormField(
                    key: const ValueKey('balance'),
                    controller: _balance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _shares ? 'Units after' : 'Balance after',
                      prefixText: _shares ? null : _moneyPrefix,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        parseNum(v ?? '') == null ? 'Number' : null,
                  ),
                ),
              ],
              const Gap(12),
              EmacsTextField(
                controller: _note,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
