/// EventEdit — edit or delete a single history entry.
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
import 'package:solidui/solidui.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/edit_fields/event_amount_field.dart';
import 'package:foliopod/pages/edit_fields/event_note_field.dart';
import 'package:foliopod/pages/event_date_row.dart';
import 'package:foliopod/services/money_format.dart';

/// Dialog to edit a history entry's type, value, date and note, or to
/// delete the entry. The caller applies the outcome via
/// AppProvider.updateEvent / deleteEvent, which replay the account's
/// history so the balance, rate and each entry's derived fields are
/// recomputed.
class EventEdit extends StatefulWidget {
  final AccountEvent event;

  /// The owning account, so the editor can offer the right entry types
  /// and label quantities as units or money. 20260729 gjw
  final Account account;

  /// Called with the edited entry when the user taps Save. The caller
  /// updates the provider and writes to the Pod.
  ///
  /// Returns a future that completes when the Pod write is done. It MUST
  /// be awaited by the caller's implementation: closing the app window
  /// waits on this before quitting, so a fire-and-forget write would be
  /// killed mid-flight and the edit silently lost.
  final Future<void> Function(AccountEvent)? onSave;

  /// Called when the user confirms Delete, to remove [event].
  final Future<void> Function()? onDelete;

  const EventEdit({
    super.key,
    required this.event,
    required this.account,
    this.onSave,
    this.onDelete,
  });

  @override
  State<EventEdit> createState() => _EventEditState();
}

class _EventEditState extends State<EventEdit> with UnsavedChangesMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _value;
  late final TextEditingController _bonus;
  late final TextEditingController _price;
  late final TextEditingController _rate;
  late final TextEditingController _note;
  late AccountEventType _type;
  late DateTime _date;

  /// The types an entry can be changed between, matching the kind of
  /// account (created stays created — it is the opening entry).
  List<AccountEventType> get _types => _shares
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

  bool get _shares => widget.account.isShares;

  bool get _superFund => widget.account.isSuper;

  bool get _isCreated => widget.event.type == AccountEventType.created;

  bool get _isRate => _type == AccountEventType.rateChange;

  bool get _isPriceUpdate => _type == AccountEventType.priceUpdate;

  bool get _isInterest => _type == AccountEventType.interest;

  bool get _isTrade =>
      _type == AccountEventType.buy || _type == AccountEventType.sell;

  /// Whether the value field holds units rather than money.
  bool get _isUnits =>
      _isTrade ||
      (_shares && (_isCreated || _type == AccountEventType.balanceUpdate));

  String? get _moneyPrefix => '${currencySymbol(widget.account.currency)} ';

  String get _valueLabel => switch (_type) {
    AccountEventType.created => _shares ? 'Opening units' : 'Opening balance',
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
    AccountEventType.balanceUpdate => _shares ? 'Units held' : 'New balance',
  };

  // Snapshot of the initial values, used to detect whether anything has
  // changed so the Save button can be enabled only when there is
  // something to save.
  late final String _initValue;
  late final String _initBonus;
  late final String _initPrice;
  late final String _initRate;
  late final String _initNote;
  late final AccountEventType _initType;
  late final DateTime _initDate;

  bool get _hasChanges =>
      _value.text != _initValue ||
      _bonus.text != _initBonus ||
      _price.text != _initPrice ||
      _rate.text != _initRate ||
      _note.text != _initNote ||
      _type != _initType ||
      _date != _initDate;

  bool get _valid =>
      parseNum(_value.text) != null &&
      (!_isCreated || parseNum(_rate.text) != null) &&
      (!_isInterest ||
          _bonus.text.trim().isEmpty ||
          parseNum(_bonus.text) != null) &&
      (!_isTrade ||
          _price.text.trim().isEmpty ||
          parseNum(_price.text) != null);

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _type = e.type;
    _date = e.date;
    // For a rate change the value field carries the rate; otherwise the
    // amount. For created events both fields are shown.
    final v = switch (_type) {
      AccountEventType.rateChange => e.rate,
      AccountEventType.priceUpdate => e.price,
      _ => e.amount,
    };
    _value = TextEditingController(
      text: switch (_type) {
        AccountEventType.rateChange => (v ?? 0).toStringAsFixed(2),
        AccountEventType.priceUpdate => formatMoney(v ?? 0),
        AccountEventType.buy || AccountEventType.sell => formatUnits(v ?? 0),
        _ when _shares && _type != AccountEventType.dividend => formatUnits(
          v ?? 0,
        ),
        _ => formatMoney(v ?? 0),
      },
    );
    _price = TextEditingController(
      text: e.price != null ? formatMoney(e.price!) : '',
    );
    _bonus = TextEditingController(
      text: e.bonus != null ? formatMoney(e.bonus!) : '',
    );
    _rate = TextEditingController(text: (e.rate ?? 0).toStringAsFixed(2));
    _note = TextEditingController(text: e.note ?? '');

    _initValue = _value.text;
    _initBonus = _bonus.text;
    _initPrice = _price.text;
    _initRate = _rate.text;
    _initNote = _note.text;
    _initType = _type;
    _initDate = _date;

    for (final c in [_value, _bonus, _price, _rate, _note]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_value, _bonus, _price, _rate, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Hand the edited entry to [EventEdit.onSave] and wait for the Pod
  /// write. Does NOT close the dialog: the window-close guard saves
  /// without popping, since the window is going, not just this route.
  /// Returns whether the save went ahead.
  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) return false;
    final v = parseNum(_value.text)!;
    final AccountEvent result;
    if (_isCreated) {
      result = widget.event.copyWith(
        date: _date,
        amount: v,
        rate: parseNum(_rate.text)!,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    } else {
      result = widget.event.copyWith(
        date: _date,
        type: _type,
        amount: _isRate || _isPriceUpdate ? null : v,
        bonus: _isInterest && _bonus.text.trim().isNotEmpty
            ? parseNum(_bonus.text)
            : null,
        price: _isPriceUpdate
            ? v
            : (_isTrade && _price.text.trim().isNotEmpty
                  ? parseNum(_price.text)
                  : null),
        rate: _isRate ? v : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    }
    // Awaited so a window close can wait for the Pod write to complete.
    await widget.onSave?.call(result);
    return true;
  }

  /// The Save button: save, then close the dialog.
  Future<void> _saveAndClose() async {
    if (await _save() && mounted) Navigator.of(context).pop();
  }

  /// The Cancel button: close, but first ask about any unsaved changes.
  Future<void> _cancel() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final action = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (action) {
      case UnsavedChangesAction.save:
        if (_valid) await _saveAndClose();
      case UnsavedChangesAction.discard:
        Navigator.of(context).pop();
      case UnsavedChangesAction.keepEditing:
        break;
    }
  }

  // Closing the whole app window prompts to save/discard just like Cancel
  // does, without popping the Navigator — the window is closing, not just
  // this route. UnsavedChangesMixin runs that prompt; it only needs to know
  // what counts as unsaved and how to save it.

  @override
  bool get hasUnsavedChanges => _hasChanges;

  @override
  bool get canSaveUnsavedChanges => _valid;

  @override
  Future<void> saveUnsavedChanges() => _save();

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          'Delete "${widget.event.description}"? The account balance and '
          'rate will be recomputed from the remaining history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.onDelete?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Entry'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCreated)
                const InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Entry',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text('Opened'),
                )
              else
                MarkdownTooltip(
                  message: '''

**Entry type**

Changing the type changes how the value is applied when the history
is replayed: buys, deposits, contributions and earnings add, sells
and fees subtract, a rate change sets the rate, a price update sets
the share price, a dividend leaves the holding unchanged, and a
balance update sets the figure outright.

''',
                  child: DropdownButtonFormField<AccountEventType>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Entry',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final t in _types)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: EventAmountField(
                      controller: _value,
                      label: _valueLabel,
                      prefix: (_isRate && !_isCreated) || _isUnits
                          ? null
                          : _moneyPrefix,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _isCreated
                        ? EventAmountField(
                            controller: _rate,
                            label: 'Rate % p.a.',
                          )
                        : EventDateRow(
                            label: 'Date',
                            value: _date,
                            onChanged: (d) => setState(() => _date = d),
                          ),
                  ),
                ],
              ),
              if (_isCreated) ...[
                const Gap(12),
                EventDateRow(
                  label: 'Date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
              ],
              if (_isTrade) ...[
                const Gap(12),
                EventAmountField(
                  fieldKey: const ValueKey('price'),
                  controller: _price,
                  label: 'Price each',
                  prefix: _moneyPrefix,
                  optional: true,
                  help: '''

**Price paid**

The per-unit price for this trade, kept for the history. The holding
is always valued at the latest market price, not this one.

''',
                ),
              ],
              if (_isInterest) ...[
                const Gap(12),
                EventAmountField(
                  fieldKey: const ValueKey('bonus'),
                  controller: _bonus,
                  label: 'Bonus interest',
                  prefix: _moneyPrefix,
                  optional: true,
                  help: '''

**Bonus interest**

Bonus interest credited together with the base interest. The base
and bonus are added together in the balance and interest totals.
Leave empty when there is no bonus.

''',
                ),
              ],
              const Gap(12),
              EventNoteField(controller: _note),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        MarkdownTooltip(
          message: _isCreated
              ? '''

**Delete**

The opening entry cannot be deleted — it carries the account's
opening balance, which anchors the replayed history.

'''
              : '''

**Delete**

Delete this history entry. The account balance and rate are
recomputed from the remaining history.

''',
          child: TextButton(
            onPressed: _isCreated ? null : _delete,
            child: const Text('Delete'),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: _cancel, child: const Text('Cancel')),
            const Gap(8),
            FilledButton(
              onPressed: _hasChanges && _valid ? _saveAndClose : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
