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

  /// The per-unit price used for [account]: the latest fetched quote,
  /// falling back to the manually entered price. Null for cash accounts
  /// and when no price is available at all.
  static double? priceFor(Account account) {
    if (!account.isShares) return null;
    return PriceService.price(account.symbol) ?? account.manualPrice;
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

  /// Income earned this financial year (interest and bonus for cash,
  /// dividends for shares) normalised to AUD.
  static double? audIncomeFY(Account account) =>
      ExchangeService.toAud(account.interestFY, account.currency);
}
