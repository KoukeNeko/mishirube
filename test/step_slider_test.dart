import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

const _sliderWidth = 300.0;

/// Pumps a slider of a known width so a drag distance maps to a value.
Future<double Function()> _pumpSlider(
  WidgetTester tester, {
  double value = 300,
  double min = 180,
  double max = 720,
  double step = 15,
}) async {
  usePhoneViewport(tester);
  var current = value;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _sliderWidth,
            child: StatefulBuilder(
              builder: (context, setState) => StepSlider(
                value: current,
                min: min,
                max: max,
                step: step,
                semanticLabel: '睡了多久',
                labelOf: (minutes) => '${minutes.round()}',
                onChanged: (next) => setState(() => current = next),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return () => current;
}

void main() {
  testWidgets('tapping the track jumps to that step', (tester) async {
    final value = await _pumpSlider(tester);
    final slider = tester.getRect(find.byType(StepSlider));

    // Halfway along: 180 + (720 - 180) / 2 = 450.
    await tester.tapAt(Offset(slider.center.dx, slider.top + 24));
    await tester.pump();

    expect(value(), 450);
  });

  testWidgets('the rail stays full width whatever the value', (tester) async {
    await _pumpSlider(tester);
    final rail = find
        .descendant(
          of: find.byType(StepSlider),
          matching: find.byType(ClipRRect),
        )
        .first;

    expect(
      tester.getSize(rail).width,
      _sliderWidth,
      reason: 'the part past the grip is still track, not empty space',
    );

    await tester.drag(find.byType(StepSlider), const Offset(-2000, 0));
    await tester.pump();
    expect(tester.getSize(rail).width, _sliderWidth);
  });

  testWidgets('dragging snaps to the step and never leaves the range', (
    tester,
  ) async {
    final value = await _pumpSlider(tester);

    await tester.drag(find.byType(StepSlider), const Offset(20, 0));
    await tester.pump();
    expect(
      value() % 15,
      0,
      reason: 'a value between steps is not a value the user picked',
    );

    await tester.drag(find.byType(StepSlider), const Offset(-2000, 0));
    await tester.pump();
    expect(value(), 180);

    await tester.drag(find.byType(StepSlider), const Offset(2000, 0));
    await tester.pump();
    expect(value(), 720);
  });

  testWidgets('each step ticks on iOS so the value can be set by feel', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpSlider(tester);

    await tester.drag(find.byType(StepSlider), const Offset(60, 0));
    await tester.pump();

    expect(haptics, isNotEmpty);
    expect(haptics.every((call) => call.contains('selectionClick')), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('screen readers get a slider they can step', (tester) async {
    final value = await _pumpSlider(tester);
    final handle = tester.ensureSemantics();
    final slider = find.byType(StepSlider);

    expect(
      tester.getSemantics(slider),
      matchesSemantics(
        label: '睡了多久',
        value: '300',
        increasedValue: '315',
        decreasedValue: '285',
        isSlider: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );

    tester.semantics.performAction(
      find.semantics.byValue('300'),
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(value(), 315);

    handle.dispose();
  });
}
