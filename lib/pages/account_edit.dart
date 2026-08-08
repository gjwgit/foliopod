/// AccountEdit — add/edit account dialog.
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

import 'package:foliopod/constants/app.dart'
    show baseCurrency, supportedCurrencies;
import 'package:foliopod/models/account.dart';
import 'package:foliopod/pages/edit_fields/account_amounts_row.dart';
import 'package:foliopod/pages/edit_fields/event_note_field.dart';
import 'package:foliopod/pages/event_date_row.dart';
import 'package:foliopod/services/money_format.dart';

/// Dialog to add a new account or edit an existing account's details.
///
/// For an existing account the balance and rate are shown read-only —
/// they change only through recorded events (Record button on the tile)
/// so the history stays a complete record. Save reports the resulting
/// [Account] through [onSave] and closes; Cancel closes without saving.
class AccountEdit extends StatefulWidget {
  final Account? account;

  /// Called with the account to store when the user taps Save. The
  /// caller updates the provider and writes to the Pod.
  ///
  /// Returns a future that completes when the Pod write is done. It MUST
  /// be awaited by the caller's implementation: closing the app window
  /// waits on this before quitting, so a fire-and-forget write would be
  /// killed mid-flight and the account silently lost.
  final Future<void> Function(Account)? onSave;

  const AccountEdit({super.key, this.account, this.onSave});

  @override
  State<AccountEdit> createState() => _AccountEditState();
}

class _AccountEditState extends State<AccountEdit> with UnsavedChangesMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _institution;
  late final TextEditingController _number;
  late final TextEditingController _balance;
  late final TextEditingController _rate;
  late final TextEditingController _symbol;
  late final TextEditingController _price;
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
  late final String _initSymbol;
  late final String _initPrice;
  late final String _initNote;
  late final AccountType _initType;
  late final String _initCurrency;
  late final bool _initIsClosed;
  late final String _initBalance;
  late final String _initRate;
  late final DateTime _initOpened;

  bool get _isNew => widget.account == null;

  /// Whether any editable field differs from its initial value. Drives
  /// the enabled state of the Save button, and whether closing asks about
  /// unsaved changes. Balance, rate and the opening date are only
  /// editable on a new account, so they count only there. 20260808 gjw
  /// Whether the user has actually altered anything since the dialog opened.
  ///
  /// This is what "unsaved" means for the close prompt: a new account nobody
  /// has typed into yet has nothing to lose, so it must not prompt. The
  /// balance, rate and opened date only count while the account is new, since
  /// afterwards they are not editable here.
  bool get _isEdited =>
      (_isNew &&
          (_balance.text != _initBalance ||
              _rate.text != _initRate ||
              _opened != _initOpened)) ||
      _name.text != _initName ||
      _institution.text != _initInstitution ||
      _number.text != _initNumber ||
      _symbol.text != _initSymbol ||
      _price.text != _initPrice ||
      _note.text != _initNote ||
      _type != _initType ||
      _currency != _initCurrency ||
      _isClosed != _initIsClosed;

  /// Whether Save should be offered.
  ///
  /// A new account can always be submitted — the form's own validation is what
  /// rejects it when incomplete — so Save stays enabled from the outset, as it
  /// did before the close prompt existed.
  bool get _hasChanges => _isNew || _isEdited;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _institution = TextEditingController(text: a?.institution ?? '');
    _number = TextEditingController(text: a?.number ?? '');
    _symbol = TextEditingController(text: a?.symbol ?? '');
    // Show the price the holding is currently marked at, however it was
    // recorded. Like the balance and rate, it is only editable when the
    // account is new; afterwards it changes through Price Update
    // entries. 20260730 gjw
    final markedPrice = a?.currentPrice ?? a?.manualPrice;
    _price = TextEditingController(
      text: markedPrice != null ? formatMoney(markedPrice) : '',
    );
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
    _initSymbol = _symbol.text;
    _initPrice = _price.text;
    _initNote = _note.text;
    _initType = _type;
    _initCurrency = _currency;
    _initIsClosed = _isClosed;
    _initBalance = _balance.text;
    _initRate = _rate.text;
    _initOpened = _opened;

    for (final c in [
      _name,
      _institution,
      _number,
      _balance,
      _rate,
      _symbol,
      _price,
      _note,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _institution,
      _number,
      _balance,
      _rate,
      _symbol,
      _price,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isShares => _type == AccountType.shares;

  bool get _isSuper => _type == AccountType.superannuation;

  /// The ticker in upper case, or null when blank.
  String? get _symbolOrNull =>
      _symbol.text.trim().isEmpty ? null : _symbol.text.trim().toUpperCase();

  /// Hand the edited account to [AccountEdit.onSave] and wait for the Pod
  /// write. Does NOT close the dialog: the window-close guard saves
  /// without popping, since the window is going, not just this route.
  /// Returns whether the save went ahead.
  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) return false;
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
        symbol: _symbolOrNull,
        openingBalance: parseNum(_balance.text) ?? 0,
        price: parseNum(_price.text),
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
        symbol: _symbolOrNull,
        isClosed: _isClosed,
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
    if (!_isEdited) {
      Navigator.of(context).pop();
      return;
    }
    final action = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (action) {
      case UnsavedChangesAction.save:
        await _saveAndClose();
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
  bool get hasUnsavedChanges => _isEdited;

  @override
  Future<void> saveUnsavedChanges() => _save();

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
                if (_isShares)
                  MarkdownTooltip(
                    message: '''

**Ticker symbol**

The market symbol used to look up the share price, for example
`MSFT` for Microsoft or `CBA.AX` for an ASX listing. Set the currency
above to the one the shares trade in.

''',
                    child: TextFormField(
                      controller: _symbol,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Ticker symbol',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  )
                else
                  TextFormField(
                    controller: _number,
                    decoration: InputDecoration(
                      labelText: _isSuper
                          ? 'Member number'
                          : 'BSB / Account number',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                const Gap(12),
                AccountAmountsRow(
                  balance: _balance,
                  price: _price,
                  rate: _rate,
                  isNew: _isNew,
                  isShares: _isShares,
                  isSuper: _isSuper,
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
                EventNoteField(controller: _note),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(
          onPressed: _hasChanges ? _saveAndClose : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
