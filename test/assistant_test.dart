import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/ai/conversation.dart';
import 'package:mishirube/backend/ai/meal_drafter.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/backend/application/ai_service.dart';
import 'package:mishirube/backend/application/assistant_tools.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/program_generator.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/assistant/assistant_screen.dart';
import 'package:mishirube/features/training/workout_summary_screen.dart';

import 'support/harness.dart';

/// A provider whose model answers as [answer] says, calling the tools it
/// is given.
class _FakeAssistant implements MealDrafter, AiConverser {
  _FakeAssistant(this.answer, {this.thought});

  final Future<String> Function(ToolRunner runTool, String message) answer;

  /// Reasoning streamed before the answer, as ChatGPT does.
  final String? thought;
  final histories = <List<AiTurn>>[];
  final instructions = <String>[];

  @override
  AiProviderKind get kind => AiProviderKind.anthropic;

  @override
  Future<String> modelName() async => 'fake-1';

  @override
  Future<AiAvailability> availability() async => AiAvailability.available;

  @override
  Future<String> converse({
    required String instructions,
    required List<AiTurn> history,
    required String message,
    required List<AiTool> tools,
    required ToolRunner runTool,
    ThinkingSink? onThinking,
  }) {
    histories.add(history);
    this.instructions.add(instructions);
    if (thought case final thought?) onThinking?.call(thought);
    return answer(runTool, message);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  AppStore storeWith(_FakeAssistant assistant) {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    return AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: backend,
      ai: AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {assistant.kind: assistant},
      )..setProvider(assistant.kind),
    )..setCloudConsent(true);
  }

  AssistantTools toolsOf(AppStore store) => AssistantTools(
    store.backend.recordTools,
    store.backend.training,
    store.backend.catalog,
    testL10n,
  );

  const request = {
    'goal': 'muscle',
    'level': 'beginner',
    'days': 3,
    'minutes': 45,
    'place': 'dumbbells',
  };

  group('the template tools', () {
    test('meet strict mode', () {
      for (final tool in AssistantTools.templateTools) {
        final properties = tool.parameters['properties']! as Map;
        expect(tool.parameters['additionalProperties'], false);
        expect(
          (tool.parameters['required']! as List).toSet(),
          properties.keys.toSet(),
          reason: tool.name,
        );
      }
      expect(
        AssistantTools.all.map((tool) => tool.name).toSet(),
        hasLength(17),
      );
      for (final aboutTemplates in [true, false]) {
        expect(
          AssistantTools.compact(aboutTemplates: aboutTemplates).length,
          lessThanOrEqualTo(5),
        );
      }
    });

    test('a program is drafted from the rules and nothing is saved', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      final tools = toolsOf(store);
      final before = store.routines.length;

      expect(tools.call('draft_program', {...request, 'days': 9}), {
        'error': 'days must be 2 to 6',
      });
      expect(
        tools.call('draft_program', {...request, 'place': 'garage'}),
        containsPair('error', startsWith('place must be one of')),
      );
      expect(tools.program, isNull);

      final answer = tools.call('draft_program', request);

      expect(answer['workouts'], hasLength(3));
      expect(tools.program!.request.days, 3);
      expect(
        tools.program!.request.equipment,
        ProgramPlace.dumbbells.equipment,
      );
      expect(store.routines, hasLength(before), reason: 'only a draft');
    });

    test('a change is checked against the template, then applied as the '
        'template is when accepted', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      final tools = toolsOf(store);
      final routine = store.routines.first;
      final kept = routine.exercises.first.exercise;
      final inRoutine = {for (final p in routine.exercises) p.exercise.id};
      final extra = store.backend.catalog.all().firstWhere(
        (exercise) => !inRoutine.contains(exercise.id),
      );

      expect(
        tools.call('routines', const {})['routines'],
        contains(containsPair('id', routine.id)),
      );
      expect(
        tools.call('propose_routine_change', {
          'routine_id': 'gone',
          'remove_exercise_ids': <String>[],
          'add_exercise_ids': [extra.id],
        }),
        containsPair('error', startsWith('no routine gone')),
      );
      expect(
        tools.call('propose_routine_change', {
          'routine_id': routine.id,
          'remove_exercise_ids': [extra.id],
          'add_exercise_ids': <String>[],
        }),
        containsPair('error', contains('is not in')),
      );

      final answer = tools.call('propose_routine_change', {
        'routine_id': routine.id,
        'remove_exercise_ids': [kept.id],
        'add_exercise_ids': [extra.id],
      });
      expect(answer['removed'], [kept.name]);
      expect(
        store.routines.first.exercises.first.exercise.id,
        kept.id,
        reason: 'nothing changes until accepted',
      );

      final applied = store.applyRoutineChange(tools.routineChange!)!;

      final ids = [for (final p in applied.exercises) p.exercise.id];
      expect(ids, isNot(contains(kept.id)));
      expect(ids.last, extra.id);
      expect(
        store.routines.firstWhere((r) => r.id == routine.id).exercises.length,
        routine.exercises.length,
      );
    });
  });

  group('the assistant page', () {
    testWidgets('a drafted program shows as a card and is kept on 儲存', (
      tester,
    ) async {
      final assistant = _FakeAssistant((runTool, message) async {
        runTool('draft_program', request);
        return '三天的草稿。';
      });
      final store = storeWith(assistant);
      final before = store.routines.length;
      await pumpScreen(tester, const AssistantScreen(), store: store);

      await tester.enterText(find.byType(TextField), '幫我排三天');
      await tester.pump();
      await tester.tap(find.byTooltip('傳送'));
      await tester.pumpAndSettle();

      expect(find.text('幫我排三天'), findsOneWidget);
      expect(find.text('三天的草稿。'), findsOneWidget);
      expect(find.text('生成的課表'), findsOneWidget);

      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(store.routines, hasLength(before + 3));
      expect(find.text('已存成 3 份課表'), findsOneWidget);
      expect(find.text('儲存'), findsNothing);

      // The next question carries the conversation so far.
      await tester.enterText(find.byType(TextField), '再一次');
      await tester.pump();
      await tester.tap(find.byTooltip('傳送'));
      await tester.pumpAndSettle();
      expect(assistant.histories.last.map((turn) => turn.text), [
        '幫我排三天',
        '三天的草稿。',
      ]);
      await disposeTree(tester);
    });

    testWidgets('what the model read opens from one line, while it works '
        'and after', (tester) async {
      final reply = Completer<String>();
      final store = storeWith(
        _FakeAssistant((runTool, message) {
          runTool('workouts', {'from': '2026-11-16', 'to': '2026-11-22'});
          return reply.future;
        }, thought: '先看這週的訓練。'),
      );
      await pumpScreen(tester, const AssistantScreen(), store: store);

      // The spinner turns until the reply comes, so nothing settles.
      const settled = Duration(milliseconds: 400);
      await tester.tap(find.text('這週練了幾次'));
      // One frame starts the scroll to the question, one ends it.
      await tester.pump();
      await tester.pump(settled);
      await tester.pump(settled);
      expect(find.text('思考中'), findsOneWidget);
      expect(find.text('讀取訓練紀錄'), findsNothing);
      await tester.tap(find.text('思考中'));
      await tester.pump(settled);
      expect(find.text('讀取訓練紀錄'), findsOneWidget);
      expect(find.text('先看這週的訓練。'), findsOneWidget);

      reply.complete('這週 3 次。');
      await tester.pumpAndSettle();
      expect(find.text('思考中'), findsNothing);
      expect(find.text('已讀取 1 項紀錄'), findsOneWidget);
      expect(find.text('讀取訓練紀錄'), findsNothing, reason: 'closed again');
      // The whole line opens it, not only its few words.
      final line = tester.getRect(
        find
            .ancestor(
              of: find.text('已讀取 1 項紀錄'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(line.height, greaterThanOrEqualTo(44));
      final page = tester.getRect(find.byType(AssistantScreen));
      await tester.tapAt(Offset(page.right - 40, line.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('讀取訓練紀錄'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('停止 drops the reply and puts the question back; 新對話 '
        'clears the page', (tester) async {
      final replies = <Completer<String>>[];
      final store = storeWith(
        _FakeAssistant((_, _) {
          replies.add(Completer());
          return replies.last.future;
        }),
      );
      await pumpScreen(tester, const AssistantScreen(), store: store);

      await tester.enterText(find.byType(TextField), '上週呢');
      await tester.pump();
      await tester.tap(find.byTooltip('傳送'));
      await tester.pump();
      await tester.tap(find.byTooltip('停止'));
      await tester.pump();
      replies.single.complete('上週 2 次。');
      await tester.pumpAndSettle();

      expect(find.text('上週 2 次。'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '上週呢',
      );

      await tester.tap(find.byTooltip('傳送'));
      await tester.pump();
      replies.last.complete('上週 2 次。');
      await tester.pumpAndSettle();
      expect(find.text('上週 2 次。'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('新對話'));
      await tester.pumpAndSettle();
      expect(find.text('上週呢'), findsNothing);
      expect(find.text('上週 2 次。'), findsNothing);
      expect(find.text('這週練了幾次'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a failure keeps the question to send again', (tester) async {
      final store = storeWith(
        _FakeAssistant(
          (_, _) async => throw const AiException(AiFailure.toolsUnsupported),
        ),
      );
      await pumpScreen(tester, const AssistantScreen(), store: store);

      await tester.enterText(find.byType(TextField), '這週練了幾次');
      await tester.pump();
      await tester.tap(find.byTooltip('傳送'));
      await tester.pumpAndSettle();

      expect(find.text('目前的 AI 不能讀紀錄，到「我的 > AI」換一個。'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '這週練了幾次',
      );
      await disposeTree(tester);
    });

    testWidgets('a finished workout opens the assistant asking for its '
        'review, with the workout as the app worked it out', (tester) async {
      final assistant = _FakeAssistant((_, _) async => '這次 12 組。');
      final store = storeWith(assistant);
      final workout = store.lastFinishedWorkout!;
      await pumpScreen(tester, const WorkoutSummaryScreen(), store: store);

      await tester.tap(find.text('AI 評語'));
      await tester.pumpAndSettle();

      expect(find.text('評這次訓練'), findsOneWidget);
      expect(find.text('這次 12 組。'), findsOneWidget);
      expect(
        find.text('已讀取 1 項紀錄'),
        findsOneWidget,
        reason: 'the workout sent with the question',
      );
      final told = assistant.instructions.single;
      expect(told, contains('"name":"${workout.routineName}"'));
      expect(
        told,
        contains('"exercise_id":"${workout.exercises.first.exercise.id}"'),
      );
      expect(told, contains('"history":{"session_count":'));
      expect(told, contains('"earlier_workouts":[{"date":'));

      // A new chat still sends this workout, so its card stays.
      await tester.tap(find.bySemanticsLabel('新對話'));
      await tester.pumpAndSettle();
      expect(find.text('這次 12 組。'), findsNothing);
      expect(find.text(workout.routineName), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a finished workout has no review without an AI', (
      tester,
    ) async {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      await pumpScreen(tester, const WorkoutSummaryScreen(), store: store);

      expect(find.text('AI 評語'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('with no AI chosen there is nothing to type in', (
      tester,
    ) async {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      await pumpScreen(tester, const AssistantScreen(), store: store);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('到「我的 > AI」設定'), findsOneWidget);
      await disposeTree(tester);
    });
  });
}
