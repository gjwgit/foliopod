# FolioPod — Your Current Financial Position

FolioPod keeps a running picture of what you are worth right now.
Today that means your bank accounts — for each one it tracks the
current balance, the current interest rate, and the interest earned
and deposits made — with shareholdings and other assets to follow, so
the one app answers the question of your current financial position.
Everything is stored encrypted in your personal
[Solid Pod](https://solidcommunity.au) so your data stays under your
control.

Where [BilliPod](https://github.com/gjwgit/billipod) watches what
goes out, FolioPod watches what you have and what it earns.

## Workflow

Add each of your accounts with its opening balance and current rate.
Then, as things happen at the bank, record them against the account:

- **Interest** credited by the bank — added to the balance. Can be
  split into base and bonus interest, added together, matching how
  banks credit bonus-rate accounts.
  While recording, the resulting balance is shown and can be edited
  to match the bank; any difference is kept as a separate balance
  update entry.
- **Deposit** — money deposited into the account.
- **Rate Change** when the bank moves the interest rate — the old
  rate is kept.
- **Balance Update** to set the balance to match the bank — the old
  balance is kept.

Every recording is an append-only, dated history entry, so the
History view is a complete record of what changed and when, including
the balance after each change. Tap an account for its transaction
log in a popup, where any entry can be edited or deleted — the
account's balance, rate and each entry's derived fields are then
recomputed by replaying the history in date order. The Accounts view
shows each account's balance, rate, and interest earned this
financial year (1 July), along with totals across your open accounts.

## Shareholdings

An account of type **Shares** holds units of a ticker rather than
cash — 100 MSFT, say. Record **Buy** and **Sell** entries to change
the units held (with the price paid kept in the history) and
**Dividend** entries for cash received, which counts as income the
same way interest does for a savings account. The holding is valued
at the latest market price, converted to AUD, and included in the
totals alongside your cash accounts.

Once a day, when a fetched price differs from the last one recorded, a
**Price Update** entry is added to the account's history, so the
history carries a daily price series alongside the transactions. The
value on display always uses the freshest fetched price, so the daily
throttle thins the history without staling any figures. You can
also add one by hand from the Record button — it is the shareholding
counterpart of a rate change on a savings account. Because the price
at any past date is known, the accounts list shows the change in value
since 1 July (on a window wide enough to fit the column), quoted in
the account's own currency: the exchange rate that applied on 1 July
is not recorded, so converting it would blend a real value change with
an unknown currency movement.

Prices come from the Yahoo Finance chart endpoint, which needs no API
key. It is not an official API: it rate limits and can change without
notice, so every failure is non-fatal — the last fetched price stays
cached for offline use, and each holding can carry a fallback price
you enter yourself, used only when no market price is available. All
of the provider-specific code sits in `_fetchQuote` in
`lib/services/price_service.dart`, so swapping providers means
rewriting one method.

Accounts can be held in any currency (AUD, USD, SGD, ...). Balances
and interest display in the account's own currency, and are
normalised to AUD wherever accounts appear together — the tile shows
an approximate AUD value and the totals bar sums in AUD. Rates are
the European Central Bank daily reference rates fetched from
frankfurter.app (no API key), cached locally so the app still works
offline, with the rates date shown in the totals tooltip. These are
daily indicative rates suited to portfolio valuation, not live forex.

Accounts you no longer use can be marked Closed to keep their history
while excluding them from totals.

The Export/Import view saves a complete JSON backup of all accounts
and their histories to a local file, and restores from a previously
saved backup. Importing merges by account id — accounts already
present are skipped, so re-importing a backup is safe.

## Data

Accounts are stored as a JSON array embedded in `accounts.ttl` in the
app's `foliopod` directory on your Pod, encrypted by
[solidpod](https://pub.dev/packages/solidpod). Use the app bar
refresh button to reload from the Pod if another instance of the app
has updated the data.

## Development

FolioPod is a Flutter app built on
[solidui](https://pub.dev/packages/solidui) and
[solidpod](https://pub.dev/packages/solidpod), following the same
architecture as the other apps in the suite (billipod, todopod,
notepod, ...).

```bash
flutter pub get
flutter run
flutter test
```

## License

GPLv3. Copyright (C) 2026, Togaware Pty Ltd.
