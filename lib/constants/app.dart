/// FolioPod - app-wide constants.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3 (the "License");
///
/// License: https://opensource.org/license/gpl-3-0
//
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://opensource.org/license/gpl-3-0>.
///
/// Authors: Graham Williams

library;

const String appName = 'FolioPod';

/// Application title displayed as the window title.

const String appTitle = 'FolioPod - Monitor Your Accounts';

/// Text shown in the SolidScaffold About dialog (accessed via the appbar
/// info button). Supports basic Markdown.

const String aboutText =
    'FolioPod keeps a running picture of your current financial '
    'position. Today that means your bank accounts — current balances, '
    'current interest rates, and the interest earned and deposits made — '
    'with shareholdings to follow. Everything is stored encrypted in '
    'your personal Solid Pod, so your data stays under your control.\n\n'
    'Add each of your accounts, then record interest and deposits as '
    'they are credited and '
    'rate changes as your bank announces them. Every change is kept as a '
    'dated history entry so you can see when rates moved and how much each '
    'account has earned.\n\n'
    '### Key features\n\n'
    '- Accounts view with balance, rate and interest earned\n'
    '- Accounts in any currency, with balances normalised to AUD using '
    'the ECB daily reference rates (frankfurter.app)\n'
    '- Shareholdings valued at the latest market price, in AUD\n'
    '- Tap an account for its transaction log in a popup\n'
    '- Edit or delete any entry — balances are recomputed by replay\n'
    '- Record interest and deposits as they are credited, on any date\n'
    '- Split interest into base and bonus interest, added together\n'
    '- State the resulting balance while recording — differences are\n'
    '  kept as a separate balance update entry\n'
    '- Record interest rate changes, keeping the old rate\n'
    '- Record balance corrections, keeping the old balance\n'
    '- Full dated history of all changes across accounts\n'
    '- Export all accounts to a JSON backup and import to restore\n'
    '- Interest totals for the current financial year\n'
    '- Security key management for encrypted data\n'
    '- Theme switching (light / dark / system)\n';

const String appDirectory = 'foliopod';
const String accountsFileName = 'accounts.ttl';

/// The currency balances are normalised to across the app. 20260729 gjw

const String baseCurrency = 'AUD';

/// Currencies offered in the account editor. All are covered by the
/// ECB daily reference rates served by frankfurter.app.

const List<String> supportedCurrencies = [
  'AUD',
  'USD',
  'SGD',
  'EUR',
  'GBP',
  'NZD',
  'JPY',
  'CHF',
  'CNY',
  'HKD',
];
