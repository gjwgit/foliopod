/// AccountEvent — a dated history record for an account.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:foliopod/services/money_format.dart' show formatUnits;

const _uuid = Uuid();

// ── Enums ─────────────────────────────────────────────────────────────────────

/// What kind of change an account event records.
enum AccountEventType {
  created,
  interest,
  deposit,
  rateChange,
  balanceUpdate,
  // Shareholding entries. 20260729 gjw
  buy,
  sell,
  dividend;

  String get label => switch (this) {
    created => 'Opened',
    interest => 'Interest',
    deposit => 'Deposit',
    rateChange => 'Rate Change',
    balanceUpdate => 'Balance Update',
    buy => 'Buy',
    sell => 'Sell',
    dividend => 'Dividend',
  };
}

// ── AccountEvent model ────────────────────────────────────────────────────────

/// A single dated entry in an account's history.
///
/// Events are append-only — the account's current balance and rate are
/// derived by applying events in order (see Account.applyEvent). The
/// interpretation of the numeric fields depends on [type]:
///
/// - created: [amount] is the opening balance, [rate] the opening rate.
/// - interest: [amount] is the base interest credited and [bonus] any
///   bonus interest credited with it; both add to the balance.
/// - deposit: [amount] is the sum deposited into the account.
/// - buy / sell: [amount] is the number of units traded and [price] the
///   per-unit price paid or received.
/// - dividend: [amount] is the cash dividend credited; units are
///   unchanged.
/// - rateChange: [rate] is the new rate; [previous] records the old rate.
/// - balanceUpdate: [amount] is the new balance; [previous] the old balance.
///
/// [balance] always records the account balance after the event was applied.

class AccountEvent {
  final String id;
  final DateTime date;
  final AccountEventType type;
  final double? amount;

  /// Bonus interest credited together with the base [amount] on an
  /// interest entry (banks often pay base and bonus interest as one
  /// transaction). 20260727 gjw
  final double? bonus;

  /// Per-unit price for a buy or sell entry, in the account's currency.
  /// Recorded for the history; valuation always uses the latest market
  /// price rather than this. 20260729 gjw
  final double? price;

  final double? rate;

  /// The value being replaced: the old rate for a rateChange, the old
  /// balance for a balanceUpdate. Filled in by Account.applyEvent.
  final double? previous;

  /// The account balance after this event was applied.
  final double? balance;

  final String? note;

  AccountEvent({
    String? id,
    required this.date,
    required this.type,
    this.amount,
    this.bonus,
    this.price,
    this.rate,
    this.previous,
    this.balance,
    this.note,
  }) : id = id ?? _uuid.v4();

  /// The total credited by this entry: base amount plus any bonus.
  double get totalAmount => (amount ?? 0) + (bonus ?? 0);

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'type': type.name,
    if (amount != null) 'amount': amount,
    if (bonus != null) 'bonus': bonus,
    if (price != null) 'price': price,
    if (rate != null) 'rate': rate,
    if (previous != null) 'previous': previous,
    if (balance != null) 'balance': balance,
    if (note != null) 'note': note,
  };

  factory AccountEvent.fromJson(Map<String, dynamic> j) => AccountEvent(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    // 20260727 gjw The deposit type was originally named income; keep
    // reading the legacy name from data stored before the rename.
    type: AccountEventType.values.firstWhere(
      (e) => e.name == (j['type'] == 'income' ? 'deposit' : j['type']),
      orElse: () => AccountEventType.balanceUpdate,
    ),
    amount: (j['amount'] as num?)?.toDouble(),
    bonus: (j['bonus'] as num?)?.toDouble(),
    price: (j['price'] as num?)?.toDouble(),
    rate: (j['rate'] as num?)?.toDouble(),
    previous: (j['previous'] as num?)?.toDouble(),
    balance: (j['balance'] as num?)?.toDouble(),
    note: j['note'] as String?,
  );

  AccountEvent copyWith({
    DateTime? date,
    AccountEventType? type,
    Object? amount = _sentinel,
    Object? bonus = _sentinel,
    Object? price = _sentinel,
    Object? rate = _sentinel,
    Object? previous = _sentinel,
    Object? balance = _sentinel,
    Object? note = _sentinel,
  }) => AccountEvent(
    id: id,
    date: date ?? this.date,
    type: type ?? this.type,
    amount: amount == _sentinel ? this.amount : amount as double?,
    bonus: bonus == _sentinel ? this.bonus : bonus as double?,
    price: price == _sentinel ? this.price : price as double?,
    rate: rate == _sentinel ? this.rate : rate as double?,
    previous: previous == _sentinel ? this.previous : previous as double?,
    balance: balance == _sentinel ? this.balance : balance as double?,
    note: note == _sentinel ? this.note : note as String?,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  static final _money = NumberFormat('#,##0.00');

  static String _rateStr(double r) => '${r.toStringAsFixed(2)}%';

  /// One-line human description of the event in the default `$` symbol.
  String get description => describe();

  /// One-line human description of the event, used in history listings.
  /// Amounts are in the owning account's currency; pass its display
  /// [symbol] (see currencySymbol in money_format.dart). For a
  /// shareholding pass its [ticker], which switches the quantity-bearing
  /// entries from money to units. 20260729 gjw
  String describe({String symbol = '\$', String? ticker}) => switch (type) {
    AccountEventType.created =>
      ticker != null
          ? 'Opened with ${formatUnits(amount ?? 0)} $ticker'
          : 'Opened with $symbol${_money.format(amount ?? 0)}'
                '${rate != null ? ' at ${_rateStr(rate!)}' : ''}',
    AccountEventType.interest =>
      bonus != null && bonus! > 0
          ? 'Interest $symbol${_money.format(totalAmount)} '
                '($symbol${_money.format(amount ?? 0)} + '
                '$symbol${_money.format(bonus!)})'
          : 'Interest $symbol${_money.format(amount ?? 0)}',
    AccountEventType.deposit => 'Deposit $symbol${_money.format(amount ?? 0)}',
    AccountEventType.rateChange =>
      'Rate '
          '${previous != null ? '${_rateStr(previous!)} → ' : ''}'
          '${_rateStr(rate ?? 0)}',
    AccountEventType.balanceUpdate =>
      ticker != null
          ? 'Units '
                '${previous != null ? '${formatUnits(previous!)} → ' : ''}'
                '${formatUnits(amount ?? 0)} $ticker'
          : 'Balance '
                '${previous != null ? '$symbol${_money.format(previous!)} → ' : ''}'
                '$symbol${_money.format(amount ?? 0)}',
    AccountEventType.buy => _trade('Buy', symbol, ticker),
    AccountEventType.sell => _trade('Sell', symbol, ticker),
    AccountEventType.dividend =>
      'Dividend $symbol${_money.format(amount ?? 0)}',
  };

  /// `Buy 50 MSFT @ US\$420.00` — the price is included when recorded.
  String _trade(String verb, String symbol, String? ticker) =>
      '$verb ${formatUnits(amount ?? 0)} ${ticker ?? 'units'}'
      '${price != null ? ' @ $symbol${_money.format(price!)}' : ''}';
}

const _sentinel = Object();
