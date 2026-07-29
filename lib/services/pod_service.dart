/// PodService — save and load encrypted accounts on a Solid Pod.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:solidpod/solidpod.dart';

import 'package:foliopod/models/account.dart';

/// Handles reading and writing accounts to a Solid Pod.
///
/// Accounts are stored as a JSON array embedded as a literal in a Turtle
/// (.ttl) file, encrypted by solidpod.

class PodService {
  PodService._();

  static const _prefixes =
      '@prefix foliopod: <https://'
      'foliopod.solidcommunity.au/ont/> .\n'
      '@prefix xsd:      <http://'
      'www.w3.org/2001/XMLSchema#> .\n';

  // ── Turtle helpers ────────────────────────────────────────────────────────

  static String _buildTtl(String fileName, String json) =>
      '$_prefixes\n'
      'foliopod:${fileName.replaceAll('.', '_')} a foliopod:AccountList ;\n'
      '  foliopod:accounts """$json""" .\n';

  static String? _extractJson(String ttl) {
    final match = RegExp(
      r'foliopod:accounts\s+"""(.*?)"""',
      dotAll: true,
    ).firstMatch(ttl);
    return match?.group(1)?.trim();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Save [accounts] to [fileName] on the pod.
  /// Returns an error message on failure, or null on success.
  static Future<String?> saveAccounts(
    String fileName,
    List<Account> accounts,
  ) async {
    try {
      final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
      final ttl = _buildTtl(fileName, json);
      await writePod(fileName, ttl, overwrite: true);
      return null;
    } catch (e) {
      debugPrint('[PodService] saveAccounts error: $e');
      return e.toString();
    }
  }

  /// Load accounts from [fileName] on the pod.
  /// Returns null on failure, empty list if file not yet created.
  static Future<List<Account>?> loadAccounts(String fileName) async {
    try {
      final ttl = await readPod(fileName);
      if (ttl.isEmpty) return [];
      final json = _extractJson(ttl);
      if (json == null || json.isEmpty) return [];
      final list = jsonDecode(json) as List;
      return list
          .map((j) => Account.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[PodService] loadAccounts error ($fileName): $e');
      return null;
    }
  }
}
