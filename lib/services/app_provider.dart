/// AppProvider — state management for FolioPod.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:foliopod/constants/app.dart';
import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/services/pod_service.dart';

/// Phases of app startup for phase-aware busy feedback.
enum StartupPhase { idle, unlocking, loading, ready }

class AppProvider extends ChangeNotifier {
  List<Account> _accounts = [];
  bool _loading = false;
  String? _error;

  // ── Startup phase ─────────────────────────────────────────────────────────

  StartupPhase _startupPhase = StartupPhase.idle;

  StartupPhase get startupPhase => _startupPhase;

  bool get isStartingUp =>
      _startupPhase == StartupPhase.unlocking ||
      _startupPhase == StartupPhase.loading;

  /// Single source of truth for "show a busy indicator, not content".
  bool get busy => _loading || isStartingUp;

  void setStartupPhase(StartupPhase phase) {
    _startupPhase = phase;
    notifyListeners();
  }

  bool get loading => _loading;
  String? get error => _error;

  // ── Accounts ──────────────────────────────────────────────────────────────

  List<Account> get allAccounts => List.unmodifiable(_accounts);

  /// Open accounts sorted by name (the main Accounts screen listing).
  List<Account> get openAccounts =>
      _sortedByName(_accounts.where((a) => !a.isClosed));

  List<Account> get closedAccounts =>
      _sortedByName(_accounts.where((a) => a.isClosed));

  static List<Account> _sortedByName(Iterable<Account> accounts) =>
      accounts.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Ticker symbols of every shareholding, for fetching prices.
  /// 20260729 gjw
  Set<String> get heldSymbols => {
    for (final a in _accounts)
      if (a.isShares && a.symbol != null && a.symbol!.isNotEmpty) a.symbol!,
  };

  /// Total balance across open accounts.
  double get totalBalance =>
      openAccounts.fold(0, (sum, a) => sum + a.currentBalance);

  /// Total interest earned this financial year across all accounts.
  double get totalInterestFY =>
      _accounts.fold(0, (sum, a) => sum + a.interestFY);

  /// Every event across all accounts paired with its account, sorted with
  /// the most recent first — the History screen listing.
  List<({Account account, AccountEvent event})> get history {
    final result = [
      for (final a in _accounts)
        for (final e in a.events) (account: a, event: e),
    ];
    result.sort((x, y) => y.event.date.compareTo(x.event.date));
    return result;
  }

  // ── Load / Save ───────────────────────────────────────────────────────────

  /// Load accounts directly — used in tests to avoid requiring a live pod.
  void loadTestData({required List<Account> accounts}) {
    _testMode = true;
    _accounts = accounts;
    _loading = false;
    notifyListeners();
  }

  bool _testMode = false;

  Future<void> loadFromPod() async {
    _loading = true;
    _error = null;
    notifyListeners();
    final loaded = await PodService.loadAccounts(accountsFileName);
    if (loaded == null) {
      _error = 'Could not load accounts from Pod.';
    } else {
      _accounts = loaded;
    }
    _loading = false;
    notifyListeners();
  }

  /// A stable content signature of the accounts, used to detect whether a
  /// reload from the Pod actually changed anything. Sorted so ordering is
  /// not a change.
  String _signature() {
    final items = _accounts.map((a) => jsonEncode(a.toJson())).toList()..sort();
    return items.join('\u0001');
  }

  /// Reloads the accounts from the Pod, replacing the in-memory data, and
  /// reports whether the Pod copy differed from what was held in memory.
  ///
  /// Returns true if the reload changed the data (the Pod was updated by
  /// another instance/app), false if the data was already up to date.
  Future<bool> refreshFromPod() async {
    final before = _signature();
    await loadFromPod();
    final after = _signature();
    return before != after;
  }

  Future<String?> saveToPod() async {
    if (_testMode) return null;
    final err = await PodService.saveAccounts(accountsFileName, _accounts);
    if (err != null) {
      _error = err;
      notifyListeners();
    }
    return err;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Merge [imported] accounts into the current data, skipping any whose
  /// id already exists (a re-import of the same backup is a no-op).
  /// Returns the number of accounts actually added. 20260727 gjw
  int importAccounts(List<Account> imported) {
    final existing = _accounts.map((a) => a.id).toSet();
    final fresh = imported.where((a) => !existing.contains(a.id)).toList();
    if (fresh.isNotEmpty) {
      _accounts = [..._accounts, ...fresh];
      notifyListeners();
    }
    return fresh.length;
  }

  void addAccount(Account account) {
    _accounts = [account, ..._accounts];
    notifyListeners();
  }

  void updateAccount(Account account) {
    _accounts = [
      for (final a in _accounts)
        if (a.id == account.id) account else a,
    ];
    notifyListeners();
  }

  void deleteAccount(String id) {
    _accounts = _accounts.where((a) => a.id != id).toList();
    notifyListeners();
  }

  /// Append [event] to the account with [accountId], updating the derived
  /// balance/rate via Account.applyEvent.
  void recordEvent(String accountId, AccountEvent event) {
    _accounts = [
      for (final a in _accounts)
        if (a.id == accountId) a.applyEvent(event) else a,
    ];
    notifyListeners();
  }

  /// Replace the history entry with [event]'s id on the account with
  /// [accountId], replaying the history so the balance, rate and each
  /// entry's derived fields are recomputed. 20260727 gjw
  void updateEvent(String accountId, AccountEvent event) {
    _accounts = [
      for (final a in _accounts)
        if (a.id == accountId)
          a.rebuilt([
            for (final e in a.events)
              if (e.id == event.id) event else e,
          ])
        else
          a,
    ];
    notifyListeners();
  }

  /// Delete the history entry with [eventId] from the account with
  /// [accountId], replaying the remaining history. 20260727 gjw
  void deleteEvent(String accountId, String eventId) {
    _accounts = [
      for (final a in _accounts)
        if (a.id == accountId)
          a.rebuilt(a.events.where((e) => e.id != eventId).toList())
        else
          a,
    ];
    notifyListeners();
  }
}
