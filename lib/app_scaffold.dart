/// AppScaffold — SolidScaffold with nav for FolioPod.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:foliopod/constants/app.dart';
import 'package:foliopod/screens/accounts_screen.dart';
import 'package:foliopod/screens/history_screen.dart';
import 'package:foliopod/screens/import_screen.dart';
import 'package:foliopod/services/app_provider.dart'
    show AppProvider, StartupPhase;
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/price_service.dart';
import 'package:foliopod/widgets/pod_refresh_action.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _isKeySaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initKeys());
  }

  Future<void> _initKeys() async {
    final provider = context.read<AppProvider>();

    // Load cached exchange rates and refresh them when stale, without
    // holding up startup — foreign balances show ≈ A\$ — until rates
    // arrive. 20260729 gjw

    unawaited(
      ExchangeService.init().then((_) {
        if (mounted) setState(() {});
      }),
    );
    unawaited(
      PriceService.init().then((_) {
        if (mounted) setState(() {});
      }),
    );

    provider.setStartupPhase(StartupPhase.unlocking);
    try {
      final webId = await getWebId();
      if (webId == null || webId.isEmpty) return;
      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);
      if (!mounted) return;
      setState(() => _isKeySaved = true);
      provider.setStartupPhase(StartupPhase.loading);
      await provider.loadFromPod();

      // Prices for whatever shareholdings were loaded, in the background
      // so a slow or blocked provider never delays the app. 20260729 gjw

      unawaited(
        PriceService.refresh(provider.heldSymbols).then((updated) {
          if (updated == 0 || !mounted) return;
          _recordPrices(provider);
        }),
      );
    } on Exception catch (e) {
      debugPrint('[AppScaffold] key/load error: $e');
    } finally {
      provider.setStartupPhase(StartupPhase.ready);
    }
  }

  /// Add a price-update entry for any holding whose price has moved and
  /// save the result, so the history carries the price series.
  /// 20260730 gjw
  Future<void> _recordPrices(AppProvider provider) async {
    final recorded = provider.recordPriceUpdates();
    if (recorded > 0) await provider.saveToPod();
    if (mounted) setState(() {});
  }

  /// Reload the accounts from the Pod and refresh the market prices and
  /// exchange rates alongside. The returned flag reports whether the Pod
  /// data itself changed, which is what the refresh action reports.
  /// 20260729 gjw
  Future<bool> _refreshAll() async {
    final provider = context.read<AppProvider>();
    final changed = await provider.refreshFromPod();
    await ExchangeService.refresh();
    await PriceService.refresh(provider.heldSymbols, force: true);
    await _recordPrices(provider);
    return changed;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    return SolidScaffold(
      showLogout: false,
      showLogin: false,
      themeToggle: const SolidThemeToggleConfig(enabled: true),
      aboutConfig: const SolidAboutConfig(
        applicationName: appName,
        applicationIcon: Icon(Icons.account_balance, size: 64),
        applicationLegalese: '© 2026 Togaware Pty Ltd',
        text: aboutText,
        readmeUrl: 'https://gjwgit.github.io/foliopod',
      ),
      appBar: SolidAppBarConfig(
        title: appName,
        versionConfig: const SolidVersionConfig(
          changelogUrl:
              'https://github.com/gjwgit/foliopod/blob/dev/CHANGELOG.md',
        ),
        actions: [
          buildPodRefreshAction(context: context, onRefresh: _refreshAll),
        ],
      ),
      menu: [
        const SolidMenuItem(
          title: 'Accounts',
          icon: Icons.account_balance,
          tooltip:
              '**Accounts**\n\n'
              'Your bank accounts with current balance, interest rate, and '
              'interest earned this financial year.',
          child: AccountsScreen(),
        ),
        const SolidMenuItem(
          title: 'Export/Import',
          icon: Icons.import_export,
          tooltip:
              '**Export/Import**\n\n'
              'Save a complete JSON backup of all your accounts and their '
              'histories, or restore from a previously saved backup.',
          child: ImportScreen(),
        ),
        const SolidMenuItem(
          title: 'History',
          icon: Icons.history,
          tooltip:
              '**History**\n\n'
              'Every recorded change across all accounts — interest and '
              'deposits credited, rate changes, and balance updates — with '
              'the date each was recorded.',
          child: HistoryScreen(),
        ),
      ],
      statusBar: SolidStatusBarConfig(
        loginStatus: const SolidLoginStatus(),
        serverInfo: const SolidServerInfo(
          serverUri: SolidConfig.defaultServerUrl,
        ),
        securityKeyStatus: SolidSecurityKeyStatus(
          isKeySaved: _isKeySaved,
          title: 'FolioPod Security Keys',
          onKeyStatusChanged: (hasKey) {
            final was = _isKeySaved;
            setState(() => _isKeySaved = hasKey);
            if (hasKey && !was) {
              context.read<AppProvider>().loadFromPod();
            }
          },
        ),
      ),
    );
  }
}
