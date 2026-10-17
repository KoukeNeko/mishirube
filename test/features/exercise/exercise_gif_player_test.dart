import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/features/exercise/exercise_gif_player.dart';

void main() {
  // ExerciseDB's shape: a rest on the first frame, then 11 steps of 100 ms.
  final delays = [
    const Duration(seconds: 1),
    for (var i = 0; i < 11; i++) const Duration(milliseconds: 100),
  ];
  Duration ms(int value) => Duration(milliseconds: value);

  test('a rest stands still, then each step runs into the next frame', () {
    expect(gifPosition(delays, Duration.zero), (frame: 0, toNext: 0.0));
    expect(gifPosition(delays, ms(999)), (frame: 0, toNext: 0.0));
    expect(gifPosition(delays, ms(1000)), (frame: 1, toNext: 0.0));
    expect(gifPosition(delays, ms(1050)), (frame: 1, toNext: 0.5));
    expect(gifPosition(delays, ms(1100)), (frame: 2, toNext: 0.0));
  });

  test(
    'the last step runs back into the first frame, and the loop repeats',
    () {
      expect(gifPosition(delays, ms(2025)).frame, 11);
      expect(gifPosition(delays, ms(2025)).toNext, closeTo(0.25, 1e-9));
      expect(gifPosition(delays, ms(2100)), (frame: 0, toNext: 0.0));
      expect(gifPosition(delays, ms(2100 + 1050)), (frame: 1, toNext: 0.5));
    },
  );

  test('a frame with no delay takes the default, as a browser gives it', () {
    final unset = [Duration.zero, Duration.zero];
    expect(gifPosition(unset, ms(50)), (frame: 0, toNext: 0.5));
    expect(gifPosition(unset, ms(100)), (frame: 1, toNext: 0.0));
  });

  test('a single picture does not move', () {
    expect(gifPosition([ms(100)], ms(40)), (frame: 0, toNext: 0.0));
    expect(gifPosition(const [], ms(40)), (frame: 0, toNext: 0.0));
  });
}
