/// Account — core data model for FolioPod.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:uuid/uuid.dart';

import 'package:foliopod/constants/app.dart' show baseCurrency;
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/services/money_format.dart'
    show formatCurrencyAmount, formatUnits;

const _uuid = Uuid();

// ── Enums ─────────────────────────────────────────────────────────────────────

/// The kind of bank account.
enum AccountType {
  savings,
  termDeposit,
  transaction,
  offset,
  // A holding of shares rather than cash: the balance counts units of
  // [Account.symbol] and the value comes from the market. 20260729 gjw
  shares,
  other;

  String get label => switch (this) {
    savings => 'Savings',
    termDeposit => 'Term Deposit',
    transaction => 'Transaction',
    offset => 'Offset',
    shares => 'Shares',
    other => 'Other',
  };
}

// ── Account model ─────────────────────────────────────────────────────────────

/// A bank account with its current balance and rate plus the full dated
/// history of events (interest, deposits, rate changes, balance updates)
/// that produced them. Mutations go through [applyEvent] so the history
/// stays consistent with the current values.

class Account {
  final String id;
  final String name;
  final String? institution;
  final AccountType type;

  /// Free-text reference such as BSB / account number (stored encrypted).
  final String? number;

  /// Ticker symbol for a shareholding, e.g. `MSFT` or `CBA.AX`. Used to
  /// fetch the market price. Null for cash accounts. 20260729 gjw
  final String? symbol;

  /// Fallback per-unit price, used when no market price has been
  /// fetched (offline, or the provider is unavailable). 20260729 gjw
  final double? manualPrice;

  /// ISO currency code of the account's balances, e.g. AUD, USD, SGD.
  /// Balances display natively and are normalised to [baseCurrency]
  /// where shown alongside other accounts. 20260729 gjw
  final String currency;

  final double currentBalance;

  /// Current interest rate as a percentage per annum, e.g. 4.35.
  final double currentRate;

  final bool isClosed;
  final String? note;
  final List<AccountEvent> events;

  Account({
    String? id,
    required this.name,
    this.institution,
    this.type = AccountType.savings,
    this.number,
    this.symbol,
    this.manualPrice,
    this.currency = baseCurrency,
    this.currentBalance = 0,
    this.currentRate = 0,
    this.isClosed = false,
    this.note,
    this.events = const [],
  }) : id = id ?? _uuid.v4();

  /// Create a new account with an opening `created` event so the opening
  /// balance and rate appear in the history.
  factory Account.open({
    required String name,
    String? institution,
    AccountType type = AccountType.savings,
    String? number,
    String? symbol,
    double? manualPrice,
    String currency = baseCurrency,
    double openingBalance = 0,
    double rate = 0,
    DateTime? date,
    String? note,
  }) =>
      Account(
        name: name,
        institution: institution,
        type: type,
        number: number,
        symbol: symbol,
        manualPrice: manualPrice,
        currency: currency,
        note: note,
      ).applyEvent(
        AccountEvent(
          date: date ?? DateTime.now(),
          type: AccountEventType.created,
          amount: openingBalance,
          rate: rate,
        ),
      );

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (institution != null) 'institution': institution,
    'type': type.name,
    if (number != null) 'number': number,
    if (symbol != null) 'symbol': symbol,
    if (manualPrice != null) 'manualPrice': manualPrice,
    'currency': currency,
    'currentBalance': currentBalance,
    'currentRate': currentRate,
    if (isClosed) 'isClosed': isClosed,
    if (note != null) 'note': note,
    'events': events.map((e) => e.toJson()).toList(),
  };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'] as String,
    name: j['name'] as String,
    institution: j['institution'] as String?,
    type: AccountType.values.firstWhere(
      (e) => e.name == j['type'],
      orElse: () => AccountType.other,
    ),
    number: j['number'] as String?,
    symbol: j['symbol'] as String?,
    manualPrice: (j['manualPrice'] as num?)?.toDouble(),
    // Accounts stored before multi-currency support default to AUD.
    currency: j['currency'] as String? ?? baseCurrency,
    currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? 0,
    currentRate: (j['currentRate'] as num?)?.toDouble() ?? 0,
    isClosed: j['isClosed'] as bool? ?? false,
    note: j['note'] as String?,
    events: (j['events'] as List? ?? [])
        .map((e) => AccountEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Account copyWith({
    String? name,
    Object? institution = _sentinel,
    AccountType? type,
    Object? number = _sentinel,
    Object? symbol = _sentinel,
    Object? manualPrice = _sentinel,
    String? currency,
    double? currentBalance,
    double? currentRate,
    bool? isClosed,
    Object? note = _sentinel,
    List<AccountEvent>? events,
  }) => Account(
    id: id,
    name: name ?? this.name,
    institution: institution == _sentinel
        ? this.institution
        : institution as String?,
    type: type ?? this.type,
    number: number == _sentinel ? this.number : number as String?,
    symbol: symbol == _sentinel ? this.symbol : symbol as String?,
    manualPrice: manualPrice == _sentinel
        ? this.manualPrice
        : manualPrice as double?,
    currency: currency ?? this.currency,
    currentBalance: currentBalance ?? this.currentBalance,
    currentRate: currentRate ?? this.currentRate,
    isClosed: isClosed ?? this.isClosed,
    note: note == _sentinel ? this.note : note as String?,
    events: events ?? this.events,
  );

  // ── Events ─────────────────────────────────────────────────────────────────

  /// Append [event] and return a new Account with the balance and rate
  /// updated accordingly. For rate changes and balance updates the value
  /// being replaced is recorded on the event as `previous`, and every
  /// event records the resulting balance, so the history is a complete
  /// record of what changed and when.
  Account applyEvent(AccountEvent event) {
    var ev = event;
    var balance = currentBalance;
    var rate = currentRate;
    switch (event.type) {
      case AccountEventType.created:
        balance = event.amount ?? 0;
        rate = event.rate ?? rate;
      case AccountEventType.interest:
      case AccountEventType.deposit:
        // For interest, base amount plus any bonus interest. 20260727 gjw
        balance += event.totalAmount;
      case AccountEventType.rateChange:
        ev = ev.copyWith(previous: currentRate);
        rate = event.rate ?? rate;
      case AccountEventType.balanceUpdate:
        ev = ev.copyWith(previous: currentBalance);
        balance = event.amount ?? balance;
      // Shareholdings: the balance counts units. A dividend is cash paid
      // out, so it earns income without changing the units held.
      case AccountEventType.buy:
        balance += event.amount ?? 0;
      case AccountEventType.sell:
        balance -= event.amount ?? 0;
      case AccountEventType.dividend:
        break;
    }
    ev = ev.copyWith(balance: balance);
    return copyWith(
      currentBalance: balance,
      currentRate: rate,
      events: [...events, ev],
    );
  }

  /// Rebuild the account from [rawEvents], recomputing the balance, rate
  /// and every event's derived `previous` and `balance` fields by
  /// replaying the events in date order (ties keep their given order).
  ///
  /// Used after a history entry is edited or deleted — a change to a past
  /// event invalidates everything derived after it, so replay from
  /// scratch rather than patch. 20260727 gjw
  Account rebuilt(List<AccountEvent> rawEvents) {
    final indexed = rawEvents.asMap().entries.toList()
      ..sort((x, y) {
        final c = x.value.date.compareTo(y.value.date);
        return c != 0 ? c : x.key.compareTo(y.key);
      });
    var account = copyWith(currentBalance: 0, currentRate: 0, events: []);
    for (final e in indexed) {
      account = account.applyEvent(
        e.value.copyWith(previous: null, balance: null),
      );
    }
    return account;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Sum of the income credited in [from, to): interest (base plus
  /// bonus) for a cash account, dividends for a shareholding, and
  /// optionally deposits. Null bounds are unbounded.
  double earned({DateTime? from, DateTime? to, bool includeDeposits = false}) =>
      events
          .where(
            (e) =>
                (e.type == AccountEventType.interest ||
                    e.type == AccountEventType.dividend ||
                    (includeDeposits && e.type == AccountEventType.deposit)) &&
                (from == null || !e.date.isBefore(from)) &&
                (to == null || e.date.isBefore(to)),
          )
          .fold(0, (sum, e) => sum + e.totalAmount);

  /// Start of the Australian financial year (1 July) containing [now].
  static DateTime fyStart(DateTime now) =>
      DateTime(now.month >= 7 ? now.year : now.year - 1, 7, 1);

  /// Interest earned this financial year.
  double get interestFY => earned(from: fyStart(DateTime.now()));

  /// Whether this account holds shares rather than cash.
  bool get isShares => type == AccountType.shares;

  /// The holding as shown to the user: `100 MSFT` for a shareholding,
  /// or the formatted balance for a cash account. 20260729 gjw
  String get holdingStr => isShares
      ? '${formatUnits(currentBalance)} ${symbol ?? 'units'}'
      : balanceStr;

  /// Formatted current balance in the account's own currency, e.g.
  /// `\$12,345.67` for AUD or `US\$12,345.67` for USD. 20260729 gjw
  String get balanceStr => formatCurrencyAmount(currentBalance, currency);

  /// The date of the most recent history entry, or null when the
  /// account has no history yet. 20260727 gjw
  DateTime? get lastEventDate => events.isEmpty
      ? null
      : events.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Formatted interest earned this financial year (since 1 July,
  /// including bonus interest), in the account's own currency. 20260727 gjw
  String get interestFYStr => formatCurrencyAmount(interestFY, currency);

  /// Formatted current rate, e.g. `4.35% p.a.`.
  String get rateStr => '${currentRate.toStringAsFixed(2)}% p.a.';
}

const _sentinel = Object();
