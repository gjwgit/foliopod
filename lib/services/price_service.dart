/// PriceService — latest share prices for valuing holdings.
///
/// Prices come from the Yahoo Finance chart endpoint, the same public
/// JSON the Yahoo site itself uses. There is no official Yahoo API and
/// no key: the endpoint is unofficial, rate limits aggressively, and can
/// change without notice, so every failure path here is non-fatal — the
/// last fetched price stays cached, and an account can carry a manually
/// entered fallback price. Keep the network details confined to
/// [_fetchQuote] so another provider can be swapped in by rewriting one
/// method. 20260729 gjw
///
/// Prices are cached device-locally in SharedPreferences (the suite's
/// ViewPrefs convention) so holdings still value when offline.
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

/// A cached quote for one symbol.
class Quote {
  final double price;

  /// Currency the price is quoted in, as reported by the provider.
  final String? currency;

  /// When the quote was fetched.
  final DateTime fetched;

  const Quote({required this.price, this.currency, required this.fetched});

  Map<String, dynamic> toJson() => {
    'price': price,
    if (currency != null) 'currency': currency,
    'fetched': fetched.toIso8601String(),
  };

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    price: (j['price'] as num).toDouble(),
    currency: j['currency'] as String?,
    fetched: DateTime.parse(j['fetched'] as String),
  );
}

class PriceService {
  PriceService._();

  static const _prefsKey = 'share_prices';

  /// Refetch when the cached quote is older than this.
  static const _staleAfter = Duration(hours: 6);

  static Map<String, Quote> _quotes = {};

  /// The cached quote for [symbol], or null when none has been fetched.
  static Quote? quote(String? symbol) =>
      symbol == null ? null : _quotes[symbol.toUpperCase()];

  /// The latest price for [symbol], or null when unavailable.
  static double? price(String? symbol) => quote(symbol)?.price;

  // ── Startup / refresh ──────────────────────────────────────────────────────

  /// Load cached quotes from local storage.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _quotes = json.map(
        (k, v) => MapEntry(k, Quote.fromJson(v as Map<String, dynamic>)),
      );
    } on Object catch (e) {
      debugPrint('[PriceService] cache load error: $e');
    }
  }

  /// Fetch quotes for [symbols], skipping any whose cached quote is still
  /// fresh unless [force] is set. Returns the number of symbols updated.
  static Future<int> refresh(
    Iterable<String> symbols, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    var updated = 0;
    for (final raw in symbols.toSet()) {
      final symbol = raw.trim().toUpperCase();
      if (symbol.isEmpty) continue;
      final cached = _quotes[symbol];
      if (!force &&
          cached != null &&
          now.difference(cached.fetched) < _staleAfter) {
        continue;
      }
      final quote = await _fetchQuote(symbol);
      if (quote != null) {
        _quotes[symbol] = quote;
        updated++;
      }
    }
    if (updated > 0) await _saveCache();
    return updated;
  }

  /// Fetch one quote. The only provider-specific code in this class.
  static Future<Quote?> _fetchQuote(String symbol) async {
    try {
      final uri = Uri.parse(
        // 20260803 gjw Split string to allow link checking.
        'https://query1.finance.yahoo.com'
        '/v8/finance/chart/'
        '${Uri.encodeComponent(symbol)}?range=1d&interval=1d',
      );
      // A browser-like User-Agent: the endpoint rejects default clients.
      final response = await http
          .get(uri, headers: const {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('[PriceService] $symbol HTTP ${response.statusCode}');
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['chart'] as Map<String, dynamic>)['result'];
      if (results is! List || results.isEmpty) return null;
      final meta =
          (results.first as Map<String, dynamic>)['meta']
              as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num?)?.toDouble();
      if (price == null) return null;
      return Quote(
        price: price,
        currency: meta['currency'] as String?,
        fetched: DateTime.now(),
      );
    } on Object catch (e) {
      debugPrint('[PriceService] $symbol fetch error: $e');
      return null;
    }
  }

  // ── Cache ──────────────────────────────────────────────────────────────────

  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_quotes.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } on Object catch (e) {
      debugPrint('[PriceService] cache save error: $e');
    }
  }

  // ── Testing ────────────────────────────────────────────────────────────────

  /// Inject quotes directly — used in tests to avoid network and prefs.
  @visibleForTesting
  static void setQuotesForTesting(Map<String, Quote> quotes) {
    _quotes = {for (final e in quotes.entries) e.key.toUpperCase(): e.value};
  }
}
