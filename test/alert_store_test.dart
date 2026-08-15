import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skypulse_pakistan/services/alert_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('idFor', () {
    test('uses the server messageId when present', () {
      expect(
        AlertStore.idFor({'messageId': 'abc-123', 'title': 'Storm'}),
        'abc-123',
      );
    });

    test('derives a stable id when the server sends none', () {
      final alert = {
        'title': 'Heavy Rain',
        'message': 'Expect 40mm',
        'timestamp': '2026-08-15T12:00:00Z',
      };

      final first = AlertStore.idFor(Map<String, dynamic>.from(alert));
      final second = AlertStore.idFor(Map<String, dynamic>.from(alert));

      expect(first, second, reason: 'must survive a refresh');
      expect(first, isNotEmpty);
    });

    test('distinguishes different alerts', () {
      final a = AlertStore.idFor({'title': 'Rain', 'timestamp': '1'});
      final b = AlertStore.idFor({'title': 'Storm', 'timestamp': '1'});
      expect(a, isNot(b));
    });
  });

  group('dismissal', () {
    test('a dismissed id stays dismissed', () async {
      // Regression: dismissals lived only in memory, so the next poll brought
      // the alert straight back.
      await AlertStore.markDismissed(['alert-1', 'alert-2']);

      final dismissed = await AlertStore.dismissedIds();
      expect(dismissed, containsAll(<String>['alert-1', 'alert-2']));
      expect(dismissed, isNot(contains('alert-3')));
    });

    test('read state persists separately from dismissal', () async {
      await AlertStore.markRead('alert-1');

      expect(await AlertStore.readIds(), contains('alert-1'));
      expect(await AlertStore.dismissedIds(), isEmpty);
    });
  });

  group('pending pushes', () {
    test('queues an alert and drains it once', () async {
      await AlertStore.addPendingPush({
        'messageId': 'push-1',
        'title': 'Flood Warning',
        'message': 'Move to higher ground',
      });

      final first = await AlertStore.takePendingPushes();
      expect(first, hasLength(1));
      expect(first.single['title'], 'Flood Warning');

      // Draining is destructive; a second read must be empty.
      expect(await AlertStore.takePendingPushes(), isEmpty);
    });

    test('does not queue the same push twice', () async {
      final alert = {'messageId': 'push-1', 'title': 'Flood Warning'};
      await AlertStore.addPendingPush(Map<String, dynamic>.from(alert));
      await AlertStore.addPendingPush(Map<String, dynamic>.from(alert));

      expect(await AlertStore.takePendingPushes(), hasLength(1));
    });
  });
}
