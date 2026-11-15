import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_condition_conflict.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/offline_condition_review.dart';
import 'package:fscm_mobile/sync/draft_submission_failure.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

import 'fixtures/offline_submission_fixture.dart';

void main() {
  ApiException conflictError(Object? details) => ApiException.fromProblem(409, {
        'code': 'conflict',
        'title': 'Conditions changed',
        'details': details,
      });

  test('valid commercial 409 requires confirmation and survives JSON storage',
      () {
    final draft = submissionDraft();
    final error = conflictError(submissionConflictJson());
    expect(error.problemDetails?['details'], isNotNull);
    final next = DraftSubmissionFailure.apply(draft, error);
    expect(next.status, SyncStatus.needsConfirmation);
    expect(next.conditionsConfirmed, isFalse);
    expect(SyncQueueLogic.canSend(next, draft.createdAt), isFalse);
    expect(next.payload.toJson(), draft.payload.toJson());
    final restored = OfflineConditionConflict.tryParse(
      jsonDecode(jsonEncode(next.conditionConflict!.toJson())),
    );
    expect(restored!.sameAs(next.conditionConflict!), isTrue);
  });

  test('ordinary or malformed 409 cannot produce a confirmation action', () {
    final draft = submissionDraft();
    for (final details in [
      null,
      {'requiresExplicitConfirmation': true},
      {...submissionConflictJson(), 'clientOrderKey': 'different-key'},
      {...submissionConflictJson(), 'offlineEstimatedAmount': 999},
      {
        ...submissionConflictJson(),
        'changedLines': [
          {'sku': 'SKU001'}
        ]
      },
    ]) {
      final next = DraftSubmissionFailure.apply(draft, conflictError(details));
      expect(next.status, SyncStatus.failed);
      expect(next.conditionConflict, isNull);
    }
  });

  test('expected conditions must refer to the original submitted products', () {
    final details = submissionConflictJson();
    final line = Map<String, dynamic>.from(
        (details['changedLines'] as List).single as Map);
    details['changedLines'] = [
      {...line, 'expectedBaseUnitPrice': 99}
    ];
    expect(
        DraftSubmissionFailure.apply(submissionDraft(), conflictError(details))
            .status,
        SyncStatus.failed);
  });

  test(
      'transport and auth failures are Failed; business validation is Rejected',
      () {
    final draft = submissionDraft();
    for (final error in [
      const ApiException.network(),
      const ApiException.timeout(),
      ApiException.fromProblem(500, null),
      ApiException.fromProblem(401, null),
      ApiException.fromProblem(403, null)
    ]) {
      expect(
          DraftSubmissionFailure.apply(draft, error).status, SyncStatus.failed);
    }
    for (final status in [400, 404, 422]) {
      final rejected = DraftSubmissionFailure.apply(
          draft, ApiException.fromProblem(status, null));
      expect(rejected.status, SyncStatus.rejected);
      expect(SyncQueueLogic.canSend(rejected, draft.createdAt), isFalse);
    }
  });

  test(
      'all six statuses are counted without losing failed or confirmation drafts',
      () {
    final draft = submissionDraft();
    expect(
        SyncQueueLogic.tabCounts(
          SyncStatus.values.map((status) => draft.copyWith(status: status)),
        ),
        {'todo': 3, 'doing': 1, 'done': 2});
  });

  testWidgets(
      'review displays amounts, MLOR and an explicit confirmation choice',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final conflict =
        OfflineConditionConflict.tryParse(submissionConflictJson())!;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => OfflineConditionReviewSheet(
                    localCode: 'OFF-TEST-0001', conflict: conflict),
              ),
          child: const Text('Review')),
    ))));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('SKU001'), findsOneWidget);
    expect(find.text('50.00% → 60.00%'), findsOneWidget);
    final sheetScrollable = find.descendant(
      of: find.byType(OfflineConditionReviewSheet),
      matching: find.byType(Scrollable),
    );
    final confirmButton = find.text('Đồng ý điều kiện mới và gửi');
    final deferButton = find.text('Để sau, giữ draft trên máy');

    // ListView builds lower children lazily; scroll as a user would.
    await tester.scrollUntilVisible(
      confirmButton,
      150,
      scrollable: sheetScrollable,
    );
    expect(confirmButton, findsOneWidget);
    await tester.scrollUntilVisible(
      deferButton,
      100,
      scrollable: sheetScrollable,
    );
    expect(deferButton, findsOneWidget);
    await tester.tap(deferButton);
    await tester.pumpAndSettle();
    expect(find.byType(OfflineConditionReviewSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
