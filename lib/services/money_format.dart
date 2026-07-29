/// Money formatting and comma-tolerant number parsing helpers.
///
/// All numeric display uses thousands separators, and all numeric input
/// fields accept them — commas are simply stripped when parsing.
/// 20260727 gjw
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00');

/// Format [value] as a money figure with thousands separators, e.g.
/// `12,345.67` (no currency symbol — callers add `$` where wanted).
String formatMoney(double value) => _money.format(value);

/// Display symbol for an ISO currency code, e.g. `US\$` for USD.
/// Unlisted codes fall back to `CODE ` as a prefix. 20260729 gjw
String currencySymbol(String code) => switch (code) {
  'AUD' => '\$',
  'USD' => 'US\$',
  'SGD' => 'S\$',
  'NZD' => 'NZ\$',
  'HKD' => 'HK\$',
  'EUR' => '€',
  'GBP' => '£',
  'JPY' => '¥',
  'CNY' => 'CN¥',
  _ => '$code ',
};

/// Format [value] with the display symbol for [code], e.g. `US\$1,234.56`.
String formatCurrencyAmount(double value, String code) =>
    '${currencySymbol(code)}${_money.format(value)}';

/// Parse a number the user typed, tolerating thousands-separator commas
/// and surrounding whitespace (e.g. `12,345.67`). Returns null when the
/// text is not a number.
double? parseNum(String text) =>
    double.tryParse(text.replaceAll(',', '').trim());
