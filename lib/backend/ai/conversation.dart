import '../../domain/domain.dart';
import 'meal_drafter.dart';

/// Runs one of the app's tools for the model: the tool's answer, or
/// `{"error": …}` when the call cannot be answered.
typedef ToolRunner = Map<String, Object?> Function(
  String name,
  Map<String, Object?> arguments,
);

/// A provider that can hold a conversation in which the model calls the
/// app's tools before it answers.
abstract interface class AiConverser {
  /// The model's answer to [message], after [history], having called
  /// [tools] through [runTool] as often as it needed, and feeding
  /// [onThinking] its reasoning where the provider streams it. Throws
  /// [AiException]; [AiFailure.toolsUnsupported] when the provider
  /// cannot call tools.
  Future<String> converse({
    required String instructions,
    required List<AiTurn> history,
    required String message,
    required List<AiTool> tools,
    required ToolRunner runTool,
    ThinkingSink? onThinking,
  });
}

/// What one request in a conversation came back with: the reply text,
/// the tools it asked for, and the messages that go back to the
/// provider so the next request carries its own calls.
typedef ToolStep = ({
  String text,
  List<AiToolCall> calls,
  List<Map<String, Object?>> echo,
});
