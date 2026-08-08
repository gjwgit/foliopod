/// Widget tests for SolidWindowCloseGuard as wired up by the editors —
/// the window-close confirmation path (save / discard / keep editing).
///
/// Runs without a live Pod: only rendering / state behaviour.
///
// Run: flutter test test/window_close_guard_test.dart

library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:solidui/solidui.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/account_edit.dart';
import 'package:foliopod/pages/event_edit.dart';
import 'package:foliopod/pages/record_event.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  Account account() => Account.open(
    name: 'Saver',
    openingBalance: 1000,
    rate: 4.0,
    date: DateTime(2026, 1, 1),
  );

  /// Pumps a host app showing [child] as a dialog, as the app does.
  Future<void> openDialog(WidgetTester tester, Widget child) async {
    // The editors are wider and taller than the default test surface.
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => child,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Unmounts everything so no resolver is left registered for the next
  /// test — the guard's resolver list is static.
  Future<void> closeAll(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  /// The unsaved-changes prompt, told apart from the editor underneath
  /// (both carry a Save button).
  final prompt = find.ancestor(
    of: find.text('You have unsaved changes. Would you like to save them?'),
    matching: find.byType(AlertDialog),
  );

  Future<void> tapPrompt(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: prompt, matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  final value = find.byKey(const ValueKey('value'));

  /// AccountEdit's Type/Currency dropdowns are wider than the half-width
  /// they are given in the 460-wide dialog, so rendering it reports a
  /// 58px overflow. That is pre-existing and nothing to do with the
  /// close guard, so it is discarded here. 20260808 gjw
  void ignorePreExistingOverflow(WidgetTester tester) {
    final e = tester.takeException();
    expect(e.toString(), contains('overflowed'));
  }

  // ── RecordEvent ────────────────────────────────────────────────────────────

  testWidgets('resolveAll succeeds with no prompt when nothing changed', (
    tester,
  ) async {
    await openDialog(tester, RecordEvent(account: account()));
    expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
    expect(find.text('Unsaved changes'), findsNothing);
    await closeAll(tester);
  });

  testWidgets('resolveAll prompts and resolves true on Discard', (
    tester,
  ) async {
    await openDialog(tester, RecordEvent(account: account()));
    await tester.enterText(value, '25');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tapPrompt(tester, 'Discard');
    expect(await future, isTrue);
    await closeAll(tester);
  });

  testWidgets('resolveAll prompts and resolves false on Keep editing', (
    tester,
  ) async {
    await openDialog(tester, RecordEvent(account: account()));
    await tester.enterText(value, '25');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();

    await tapPrompt(tester, 'Keep editing');
    expect(await future, isFalse);
    // The editor is still open with the unsaved amount intact.
    expect(find.text('25'), findsOneWidget);
    await closeAll(tester);
  });

  // Regression: onSave used to be the popped dialog result, so the Pod
  // write only started once the dialog closed. resolveAll() returned
  // immediately, the window was destroyed, and the entry was lost despite
  // tapping Save.
  testWidgets('window-close Save waits for the Pod write to finish', (
    tester,
  ) async {
    final podWrite = Completer<void>();
    var written = false;

    await openDialog(
      tester,
      RecordEvent(
        account: account(),
        onSave: (events) async {
          await podWrite.future;
          written = true;
        },
      ),
    );
    await tester.enterText(value, '25');
    await tester.pump();

    var resolved = false;
    final future = SolidWindowCloseGuard.resolveAll()
      ..then((_) => resolved = true);
    await tester.pumpAndSettle();

    await tapPrompt(tester, 'Save');

    // The Pod write is still in flight, so the guard must NOT have
    // resolved — otherwise the caller would destroy the window and lose
    // the entry.
    expect(resolved, isFalse);
    expect(written, isFalse);

    podWrite.complete();
    await tester.pumpAndSettle();

    expect(await future, isTrue);
    expect(written, isTrue);
    await closeAll(tester);
  });

  testWidgets('editor unregisters its resolver on dispose', (tester) async {
    await openDialog(tester, RecordEvent(account: account()));
    await tester.enterText(value, '25');
    await tester.pump();
    await closeAll(tester);
    // No editor left registered, so nothing to resolve.
    expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
    expect(find.text('Unsaved changes'), findsNothing);
  });

  // ── AccountEdit ────────────────────────────────────────────────────────────

  testWidgets('AccountEdit does not prompt for an untouched new account', (
    tester,
  ) async {
    await openDialog(tester, const AccountEdit());
    ignorePreExistingOverflow(tester);
    expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
    expect(find.text('Unsaved changes'), findsNothing);
    await closeAll(tester);
  });

  // The Save button and the close prompt answer different questions. A new
  // account can always be submitted (validation rejects it if incomplete), but
  // an untouched new dialog has nothing to lose and must not prompt. These
  // were briefly collapsed into one getter, which disabled Save on a fresh
  // Add Account dialog.
  testWidgets('AccountEdit offers Save on an untouched new account', (
    tester,
  ) async {
    await openDialog(tester, const AccountEdit());
    ignorePreExistingOverflow(tester);

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNotNull);
    await closeAll(tester);
  });

  testWidgets('AccountEdit prompts once the new account is edited', (
    tester,
  ) async {
    await openDialog(tester, const AccountEdit());
    ignorePreExistingOverflow(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Everyday');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tapPrompt(tester, 'Discard');
    expect(await future, isTrue);
    await closeAll(tester);
  });

  testWidgets('AccountEdit window-close Save reports the account', (
    tester,
  ) async {
    Account? saved;
    await openDialog(tester, AccountEdit(onSave: (a) async => saved = a));
    ignorePreExistingOverflow(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Everyday');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();
    await tapPrompt(tester, 'Save');

    expect(await future, isTrue);
    expect(saved?.name, 'Everyday');
    await closeAll(tester);
  });

  // ── EventEdit ──────────────────────────────────────────────────────────────

  testWidgets('EventEdit prompts and keeps the edit on Keep editing', (
    tester,
  ) async {
    final a = account();
    AccountEvent? saved;
    await openDialog(
      tester,
      EventEdit(
        event: a.events.first,
        account: a,
        onSave: (e) async => saved = e,
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '1500');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();
    await tapPrompt(tester, 'Keep editing');

    expect(await future, isFalse);
    expect(saved, isNull);
    expect(find.text('1500'), findsOneWidget);
    await closeAll(tester);
  });

  testWidgets('EventEdit window-close Save reports the edited entry', (
    tester,
  ) async {
    final a = account();
    AccountEvent? saved;
    await openDialog(
      tester,
      EventEdit(
        event: a.events.first,
        account: a,
        onSave: (e) async => saved = e,
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, '1500');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();
    await tapPrompt(tester, 'Save');

    expect(await future, isTrue);
    expect(saved?.amount, 1500);
    await closeAll(tester);
  });
}
