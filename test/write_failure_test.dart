// Tests that a Pod write fired from a background refresh reports its failure
// instead of dropping it, via SolidWriteFailures.watch.
//
// Runs without a live Pod: the save is stubbed by a fake provider that
// returns the error-string convention saveToPod uses (null on success).

import 'package:flutter_test/flutter_test.dart';
import 'package:solidui/solidui.dart';

import 'package:foliopod/services/app_provider.dart';

/// Provider that never touches the Pod. [saveError] is what saveToPod
/// completes with — null for a successful save.

class FakeProvider extends AppProvider {
  FakeProvider({this.saveError});

  final String? saveError;

  @override
  Future<String?> saveToPod() async => saveError;
}

void main() {
  setUp(SolidWriteFailures.clear);

  test('a save completing with an error String is reported', () async {
    final provider = FakeProvider(saveError: 'Pod unreachable');
    SolidWriteFailures.watch(
      provider.saveToPod(),
      during: 'saving updated prices',
    );
    await Future<void>.delayed(Duration.zero);

    expect(SolidWriteFailures.latest.value, contains('Pod unreachable'));
    expect(
      SolidWriteFailures.latest.value,
      contains('Failed saving updated prices.'),
    );
  });

  test('a save completing with null reports nothing', () async {
    final provider = FakeProvider();
    SolidWriteFailures.watch(
      provider.saveToPod(),
      during: 'saving updated prices',
    );
    await Future<void>.delayed(Duration.zero);

    expect(SolidWriteFailures.latest.value, isNull);
  });

  test('a save that throws is reported', () async {
    SolidWriteFailures.watch(
      Future<String?>.error(StateError('boom')),
      during: 'saving updated prices',
    );
    await Future<void>.delayed(Duration.zero);

    expect(SolidWriteFailures.latest.value, contains('boom'));
  });
}
