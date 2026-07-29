/// AccountEdit — add/edit account dialog.
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

import 'package:foliopod/constants/app.dart'
    show baseCurrency, supportedCurrencies;
import 'package:foliopod/models/account.dart';
import 'package:foliopod/pages/event_date_row.dart';
import 'package:foliopod/services/money_format.dart';

/// Dialog to add a new account or edit an existing account's details.
///
/// For an existing account the balance and rate are shown read-only —
/// they change only through recorded events (Record button on the tile)
/// so the history stays a complete record. Pops the resulting [Account]
/// on Save, or null on Cancel.
class AccountEdit extends StatefulWidget {
  final Account? account;
  const AccountEdit({super.key, this.account});

  @override
  State<AccountEdit> createState() => _AccountEditState();
}

class _AccountEditState extends State<AccountEdit> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _institution;
  late final TextEditingController _number;
  late final TextEditingController _balance;
  late final TextEditingController _rate;
  late final TextEditingController _note;
  late AccountType _type;
  late String _currency;
  late bool _isClosed;
  DateTime _opened = DateTime.now();

  // Snapshot of the initial values, used to detect whether anything has
  // changed so the Save button can be enabled only when there is
  // something to save.
  late final String _initName;
  late final String _initInstitution;
  late final String _initNumber;
  late final String _initNote;
  late final AccountType _initType;
  late final String _initCurrency;
  late final bool _initIsClosed;

  bool get _isNew => widget.account == null;

  /// Whether any editable field differs from its initial value. Drives
  /// the enabled state of the Save button. A new account always counts
  /// as changed once it has a name.
  bool get _hasChanges =>
      _isNew ||
      _name.text != _initName ||
      _institution.text != _initInstitution ||
      _number.text != _initNumber ||
      _note.text != _initNote ||
      _type != _initType ||
      _currency != _initCurrency ||
      _isClosed != _initIsClosed;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _institution = TextEditingController(text: a?.institution ?? '');
    _number = TextEditingController(text: a?.number ?? '');
    _balance = TextEditingController(
      text: a != null ? formatMoney(a.currentBalance) : '',
    );
    _rate = TextEditingController(
      text: a != null ? a.currentRate.toStringAsFixed(2) : '',
    );
    _note = TextEditingController(text: a?.note ?? '');
    _type = a?.type ?? AccountType.savings;
    _currency = a?.currency ?? baseCurrency;
    _isClosed = a?.isClosed ?? false;

    _initName = _name.text;
    _initInstitution = _institution.text;
    _initNumber = _number.text;
    _initNote = _note.text;
    _initType = _type;
    _initCurrency = _currency;
    _initIsClosed = _isClosed;

    for (final c in [_name, _institution, _number, _note]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _institution, _number, _balance, _rate, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _balanceHelp => _isNew
      ? '''

**Opening balance**

The opening balance of the account, recorded as the first history
entry.

'''
      : '''

**Balance**

The current balance changes only through recorded events so the
history stays complete. Use the Record button on the account to
update it.

''';

  String get _rateHelp => _isNew
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final Account result;
    if (_isNew) {
      result = Account.open(
        name: _name.text.trim(),
        institution: _institution.text.trim().isEmpty
            ? null
            : _institution.text.trim(),
        type: _type,
        currency: _currency,
        number: _number.text.trim().isEmpty ? null : _number.text.trim(),
        openingBalance: parseNum(_balance.text) ?? 0,
        rate: parseNum(_rate.text) ?? 0,
        date: _opened,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    } else {
      result = widget.account!.copyWith(
        name: _name.text.trim(),
        institution: _institution.text.trim().isEmpty
            ? null
            : _institution.text.trim(),
        type: _type,
        currency: _currency,
        number: _number.text.trim().isEmpty ? null : _number.text.trim(),
        isClosed: _isClosed,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Add Account' : 'Edit Account'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: _isNew,
                  decoration: const InputDecoration(
                    labelText: 'Account name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const Gap(12),
                TextFormField(
                  controller: _institution,
                  decoration: const InputDecoration(
                    labelText: 'Institution',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AccountType>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final t in AccountType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (v) => setState(() => _type = v!),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: MarkdownTooltip(
                        message: '''

**Currency**

The currency this account is held in. Balances and interest display
in this currency and are normalised to AUD wherever accounts are
shown together, using the ECB daily reference rates.

''',
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final c in supportedCurrencies)
                              DropdownMenuItem(value: c, child: Text(c)),
                          ],
                          onChanged: (v) => setState(() => _currency = v!),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(
                    labelText: 'BSB / Account number',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: MarkdownTooltip(
                        message: _balanceHelp,
                        child: TextFormField(
                          controller: _balance,
                          enabled: _isNew,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _isNew ? 'Opening balance' : 'Balance',
                            prefixText: '\$ ',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: MarkdownTooltip(
                        message: _rateHelp,
                        child: TextFormField(
                          controller: _rate,
                          enabled: _isNew,
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
                ),
                const Gap(12),
                if (_isNew)
                  EventDateRow(
                    label: 'Opened',
                    value: _opened,
                    onChanged: (d) => setState(() => _opened = d),
                  )
                else
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Closed'),
                    subtitle: const Text(
                      'Keep the history but exclude from totals.',
                    ),
                    value: _isClosed,
                    onChanged: (v) => setState(() => _isClosed = v),
                  ),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _hasChanges ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
