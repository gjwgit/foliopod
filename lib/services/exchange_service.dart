/// ExchangeService — daily exchange rates for normalising to AUD.
///
/// Rates come from the Frankfurter API (https://frankfurter.app), an open
/// source service publishing the European Central Bank's daily reference
/// rates — no API key required. These are daily indicative rates (one
/// publication per business day), suitable for portfolio valuation, not
/// live forex. 20260729 gjw
///
/// The latest fetched rates are cached device-locally in SharedPreferences
/// (thin static wrapper, per the suite's ViewPrefs convention) so foreign
/// balances still normalise when offline; the rates date is kept alongside
/// and surfaced in the UI.
///
// Time-stamp: <2026-07-29>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foliopod/constants/app.dart';

class ExchangeService {
  ExchangeService._();

  /// SharedPreferences key holding the cached rates JSON.
  static const _prefsKey = 'exchange_rates_$baseCurrency';

  /// Refetch when the cached rates are older than this.
  static const _staleAfter = Duration(hours: 18);

  /// Rates from [baseCurrency] to each currency code, e.g.
  /// {'USD': 0.65, 'SGD': 0.88}.
  static Map<String, double>? _rates;

  /// The date the ECB published the cached rates.
  static DateTime? _ratesDate;

  /// When the rates were last fetched from the network.
  static DateTime? _fetched;

  /// The publication date of the rates in use, or null when no rates are
  /// available yet.
  static DateTime? get ratesDate => _ratesDate;

  static bool get hasRates => _rates != null;

  // ── Conversion ─────────────────────────────────────────────────────────────

  /// Convert [amount] of [currency] to AUD, or null when no rate is
  /// available for the currency. AUD passes through unchanged.
  static double? toAud(double amount, String currency) {
    if (currency == baseCurrency) return amount;
    final rate = _rates?[currency];
    if (rate == null || rate == 0) return null;
    return amount / rate;
  }

  /// The value of A\$1 in [currency], e.g. ~0.65 for USD — the ECB
  /// AUD-based rate as published, whose inverse [toAud] applies. Null
  /// when no rate is available. 20260729 gjw
  static double? rateFromAud(String currency) {
    if (currency == baseCurrency) return 1;
    return _rates?[currency];
  }

  // ── Startup / refresh ──────────────────────────────────────────────────────

  /// Load cached rates then refresh from the network when they are stale.
  /// Safe to fire-and-forget at startup — failures leave the cached (or
  /// no) rates in place.
  static Future<void> init() async {
    await _loadCache();
    final fetched = _fetched;
    if (fetched == null || DateTime.now().difference(fetched) > _staleAfter) {
      await refresh();
    }
  }

  /// Fetch the latest rates from Frankfurter and cache them locally.
  /// Returns true on success.
  static Future<bool> refresh() async {
    try {
      final uri = Uri.parse(
        'https://api.frankfurter.app/latest?from=$baseCurrency',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('[ExchangeService] refresh HTTP ${response.statusCode}');
        return false;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = (body['rates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
      _rates = rates;
      _ratesDate = DateTime.tryParse(body['date'] as String? ?? '');
      _fetched = DateTime.now();
      await _saveCache();
      debugPrint(
        '[ExchangeService] refreshed ${rates.length} rates '
        'dated $_ratesDate',
      );
      return true;
    } on Object catch (e) {
      debugPrint('[ExchangeService] refresh error: $e');
      return false;
    }
  }

  // ── Cache ──────────────────────────────────────────────────────────────────

  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'rates': _rates,
          'date': _ratesDate?.toIso8601String(),
          'fetched': _fetched?.toIso8601String(),
        }),
      );
    } on Object catch (e) {
      debugPrint('[ExchangeService] cache save error: $e');
    }
  }

  static Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _rates = (json['rates'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
      _ratesDate = DateTime.tryParse(json['date'] as String? ?? '');
      _fetched = DateTime.tryParse(json['fetched'] as String? ?? '');
    } on Object catch (e) {
      debugPrint('[ExchangeService] cache load error: $e');
    }
  }

  // ── Testing ────────────────────────────────────────────────────────────────

  /// Inject rates directly — used in tests to avoid network and prefs.
  @visibleForTesting
  static void setRatesForTesting(Map<String, double>? rates, {DateTime? date}) {
    _rates = rates;
    _ratesDate = date;
    _fetched = rates == null ? null : DateTime.now();
  }
}
