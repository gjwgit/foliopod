/// EventEdit — edit or delete a single history entry.
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

import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/event_date_row.dart';
import 'package:foliopod/services/money_format.dart';

/// The outcome of an [EventEdit] dialog: the edited event on Save, or
/// deleted true on Delete. The dialog pops null on Cancel.
typedef EventEditResult = ({AccountEvent? event, bool deleted});

/// Dialog to edit a history entry's type, value, date and note, or to
/// delete the entry. The caller applies the result via
/// AppProvider.updateEvent / deleteEvent, which replay the account's
/// history so the balance, rate and each entry's derived fields are
/// recomputed.
class EventEdit extends StatefulWidget {
  final AccountEvent event;
  const EventEdit({super.key, required this.event});

  @override
  State<EventEdit> createState() => _EventEditState();
}

class _EventEditState extends State<EventEdit> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _value;
  late final TextEditingController _bonus;
  late final TextEditingController _rate;
  late final TextEditingController _note;
  late AccountEventType _type;
  late DateTime _date;

  /// The types an entry can be changed between (created stays created —
  /// it is the account's opening entry).
  static const _types = [
    AccountEventType.interest,
    AccountEventType.deposit,
    AccountEventType.rateChange,
    AccountEventType.balanceUpdate,
  ];

  bool get _isCreated => widget.event.type == AccountEventType.created;

  bool get _isRate => _type == AccountEventType.rateChange;

  bool get _isInterest => _type == AccountEventType.interest;

  String get _valueLabel => switch (_type) {
    AccountEventType.created => 'Opening balance',
    AccountEventType.interest => 'Base interest',
    AccountEventType.deposit => 'Amount deposited',
    AccountEventType.rateChange => 'New rate % p.a.',
    AccountEventType.balanceUpdate => 'New balance',
  };

  // Snapshot of the initial values, used to detect whether anything has
  // changed so the Save button can be enabled only when there is
  // something to save.
  late final String _initValue;
  late final String _initBonus;
  late final String _initRate;
  late final String _initNote;
  late final AccountEventType _initType;
  late final DateTime _initDate;

  bool get _hasChanges =>
      _value.text != _initValue ||
      _bonus.text != _initBonus ||
      _rate.text != _initRate ||
      _note.text != _initNote ||
      _type != _initType ||
      _date != _initDate;

  bool get _valid =>
      parseNum(_value.text) != null &&
      (!_isCreated || parseNum(_rate.text) != null) &&
      (!_isInterest ||
          _bonus.text.trim().isEmpty ||
          parseNum(_bonus.text) != null);

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _type = e.type;
    _date = e.date;
    // For a rate change the value field carries the rate; otherwise the
    // amount. For created events both fields are shown.
    final v = _type == AccountEventType.rateChange ? e.rate : e.amount;
    _value = TextEditingController(
      text: _type == AccountEventType.rateChange
          ? (v ?? 0).toStringAsFixed(2)
          : formatMoney(v ?? 0),
    );
    _bonus = TextEditingController(
      text: e.bonus != null ? formatMoney(e.bonus!) : '',
    );
    _rate = TextEditingController(text: (e.rate ?? 0).toStringAsFixed(2));
    _note = TextEditingController(text: e.note ?? '');

    _initValue = _value.text;
    _initBonus = _bonus.text;
    _initRate = _rate.text;
    _initNote = _note.text;
    _initType = _type;
    _initDate = _date;

    for (final c in [_value, _bonus, _rate, _note]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_value, _bonus, _rate, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
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
        amount: _isRate ? null : v,
        bonus: _isInterest && _bonus.text.trim().isNotEmpty
            ? parseNum(_bonus.text)
            : null,
        rate: _isRate ? v : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    }
    Navigator.of(context).pop<EventEditResult>((event: result, deleted: false));
  }

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
    Navigator.of(context).pop<EventEditResult>((event: null, deleted: true));
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
is replayed: interest and deposits add to the balance, a rate change
sets the rate, and a balance update sets the balance.

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
                    child: TextFormField(
                      controller: _value,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _valueLabel,
                        prefixText: _isRate && !_isCreated ? null : '\$ ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) =>
                          parseNum(v ?? '') == null ? 'Number' : null,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: _isCreated
                        ? TextFormField(
                            controller: _rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Rate % p.a.',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) =>
                                parseNum(v ?? '') == null ? 'Number' : null,
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
              if (_isInterest) ...[
                const Gap(12),
                MarkdownTooltip(
                  message: '''

**Bonus interest**

Bonus interest credited together with the base interest. The base
and bonus are added together in the balance and interest totals.
Leave empty when there is no bonus.

''',
                  child: TextFormField(
                    key: const ValueKey('bonus'),
                    controller: _bonus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Bonus interest',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty || parseNum(v) != null)
                        ? null
                        : 'Number',
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const Gap(8),
            FilledButton(
              onPressed: _hasChanges && _valid ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
