/// PortfolioService — value accounts natively and in AUD.
///
/// The one place that knows how an account turns into a number: a cash
/// account is worth its balance, a shareholding is worth its units times
/// the latest share price. Valuation lives here rather than on Account so
/// the model stays free of the price and rate services. 20260729 gjw
///
// Time-stamp: <2026-07-29>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:foliopod/models/account.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/price_service.dart';

class PortfolioService {
  PortfolioService._();

  /// The per-unit price used for [account], in order of preference: the
  /// latest fetched quote, the last price recorded in the account's
  /// history, then the legacy fallback price. Null for cash accounts and
  /// when no price is available at all. 20260730 gjw
  static double? priceFor(Account account) {
    if (!account.isShares) return null;
    return PriceService.price(account.symbol) ??
        account.currentPrice ??
        account.manualPrice;
  }

  /// The value of the holding in the account's own currency: the cash
  /// balance, or units times price for a shareholding. Null when a share
  /// price is not available.
  static double? nativeValue(Account account) {
    if (!account.isShares) return account.currentBalance;
    final price = priceFor(account);
    return price == null ? null : account.currentBalance * price;
  }

  /// The value of the holding normalised to AUD, or null when either the
  /// share price or the exchange rate is unavailable.
  static double? audValue(Account account) {
    final native = nativeValue(account);
    if (native == null) return null;
    return ExchangeService.toAud(native, account.currency);
  }

  /// The value of the holding in its own currency as it stood
  /// immediately before [date], for comparing against today. A
  /// shareholding is valued at the price recorded by then, so this is
  /// null when no price had been recorded — unless nothing was held, in
  /// which case it is zero. 20260730 gjw
  static double? nativeValueAt(Account account, DateTime date) {
    final quantity = account.balanceAt(date);
    if (!account.isShares) return quantity;
    if (quantity == 0) return 0;
    final price = account.priceAt(date);
    return price == null ? null : quantity * price;
  }

  /// The change in the holding's value since the start of the current
  /// financial year (1 July), in the account's own currency. Null when
  /// either end of the comparison cannot be valued.
  ///
  /// Deliberately not converted to AUD: the exchange rate that applied
  /// on 1 July is not recorded, so a converted figure would mix a real
  /// value change with an unknowable currency movement. 20260730 gjw
  static double? changeSinceFYStart(Account account) {
    final now = nativeValue(account);
    if (now == null) return null;
    final then = nativeValueAt(account, Account.fyStart(DateTime.now()));
    return then == null ? null : now - then;
  }

  /// What the account would earn in a month at its current rate: a
  /// twelfth of the annual rate applied to the balance, in the account's
  /// own currency. Null when there is no rate to work from — a
  /// shareholding, or a fund with no crediting rate recorded.
  ///
  /// Deliberately a plain nominal twelfth rather than a compounded
  /// monthly rate: it is the figure a rate quoted "per annum" implies
  /// for a month, and it makes the arithmetic checkable by hand.
  /// 20260731 gjw
  static double? estimatedMonthly(Account account) {
    if (account.isShares || account.currentRate == 0) return null;
    return account.currentBalance * account.currentRate / 100 / 12;
  }

  /// The monthly estimate normalised to AUD. Null when the account has
  /// no rate to work from, or when its currency cannot be converted.
  /// 20260731 gjw
  static double? audEstimatedMonthly(Account account) {
    final monthly = estimatedMonthly(account);
    if (monthly == null) return null;
    return ExchangeService.toAud(monthly, account.currency);
  }

  /// Income earned this financial year (interest and bonus for cash,
  /// dividends for shares) normalised to AUD.
  static double? audIncomeFY(Account account) =>
      ExchangeService.toAud(account.interestFY, account.currency);
}
