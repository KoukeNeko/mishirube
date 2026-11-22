import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/backend/ai/chatgpt_drafter.dart';
import 'package:mishirube/backend/ai/cloud_drafter.dart';
import 'package:mishirube/backend/ai/copilot_drafter.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/domain/domain.dart';

const _tool = AiTool(
  name: 'workouts',
  description: 'Workouts in a period.',
  parameters: {
    'type': 'object',
    'properties': {
      'from': {'type': 'string'},
    },
    'required': ['from'],
    'additionalProperties': false,
  },
);

/// Answers each request with the next of [replies], keeping the bodies
/// sent.
({http.Client client, List<Map<String, dynamic>> sent}) _server(
  List<String> replies, {
  String? Function(http.Request request)? other,
}) {
  final sent = <Map<String, dynamic>>[];
  final client = MockClient((request) async {
    if (other?.call(request) case final String body) {
      return http.Response.bytes(utf8.encode(body), 200);
    }
    sent.add(jsonDecode(request.body) as Map<String, dynamic>);
    return http.Response.bytes(utf8.encode(replies[sent.length - 1]), 200);
  });
  return (client: client, sent: sent);
}

void main() {
  late List<(String, Map<String, Object?>)> ran;

  Map<String, Object?> runTool(String name, Map<String, Object?> arguments) {
    ran.add((name, arguments));
    return {'workout_count': 3};
  }

  Future<String> converse(CloudDrafter drafter) => drafter.converse(
    instructions: 'Answer from the tools.',
    history: const [
      AiTurn(AiSpeaker.user, '上週呢'),
      AiTurn(AiSpeaker.assistant, '上週 2 次。'),
    ],
    message: '這週練了幾次',
    tools: const [_tool],
    runTool: runTool,
  );

  setUp(() => ran = []);

  test('Anthropic runs the tool and answers from its result', () async {
    final server = _server([
      jsonEncode({
        'content': [
          {
            'type': 'tool_use',
            'id': 'tu_1',
            'name': 'workouts',
            'input': {'from': '2026-11-16'},
          },
        ],
        'stop_reason': 'tool_use',
      }),
      jsonEncode({
        'content': [
          {'type': 'text', 'text': '這週 3 次。'},
        ],
      }),
    ]);
    final drafter = AnthropicDrafter(
      client: server.client,
      readKey: () async => 'k',
      readModel: () => 'claude',
    );

    expect(await converse(drafter), '這週 3 次。');
    expect(ran.single.$1, 'workouts');
    expect(ran.single.$2, {'from': '2026-11-16'});
    final first = server.sent.first;
    expect(first['tools'], [
      {
        'name': 'workouts',
        'description': 'Workouts in a period.',
        'input_schema': _tool.parameters,
      },
    ]);
    expect(first['messages'], hasLength(3), reason: 'history, then the ask');
    final messages = server.sent.last['messages'] as List;
    expect(messages[3], containsPair('role', 'assistant'));
    expect(messages[4], {
      'role': 'user',
      'content': [
        {
          'type': 'tool_result',
          'tool_use_id': 'tu_1',
          'content': '{"workout_count":3}',
        },
      ],
    });
  });

  test('Gemini echoes the call with its signature and sends the response '
      'by name', () async {
    final call = {
      'functionCall': {
        'name': 'workouts',
        'args': {'from': '2026-11-16'},
      },
      'thoughtSignature': 'sig',
    };
    final server = _server([
      jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [call],
            },
          },
        ],
      }),
      jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': '這週 3 次。'},
              ],
            },
          },
        ],
      }),
    ]);
    final drafter = GoogleAiStudioDrafter(
      client: server.client,
      readKey: () async => 'k',
      readModel: () => 'gemini',
    );

    expect(await converse(drafter), '這週 3 次。');
    expect(ran.single.$1, 'workouts');
    final first = server.sent.first;
    expect(
      (first['tools'] as List).single,
      containsPair('functionDeclarations', [
        {
          'name': 'workouts',
          'description': 'Workouts in a period.',
          'parametersJsonSchema': _tool.parameters,
        },
      ]),
    );
    expect((first['contents'] as List)[1], {
      'role': 'model',
      'parts': [
        {'text': '上週 2 次。'},
      ],
    });
    final contents = server.sent.last['contents'] as List;
    expect(contents[3], {
      'role': 'model',
      'parts': [call],
    });
    expect(contents[4], {
      'role': 'user',
      'parts': [
        {
          'functionResponse': {
            'name': 'workouts',
            'response': {'workout_count': 3},
          },
        },
      ],
    });
  });

  test(
    'an OpenAI-shaped endpoint gets strict functions and tool messages',
    () async {
      final server = _server([
        jsonEncode({
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': null,
                'tool_calls': [
                  {
                    'id': 'call_1',
                    'type': 'function',
                    'function': {
                      'name': 'workouts',
                      'arguments': '{"from":"2026-11-16"}',
                    },
                  },
                ],
              },
            },
          ],
        }),
        jsonEncode({
          'choices': [
            {
              'message': {'role': 'assistant', 'content': '這週 3 次。'},
            },
          ],
        }),
      ]);
      final drafter = OpenAiCompatibleDrafter(
        client: server.client,
        readKey: () async => 'k',
        readModel: () => 'gpt',
        readEndpoint: () => 'https://example.com/v1',
      );

      expect(await converse(drafter), '這週 3 次。');
      expect(ran.single.$1, 'workouts');
      expect(ran.single.$2, {'from': '2026-11-16'});
      expect(
        (server.sent.first['tools'] as List).single,
        containsPair('function', containsPair('strict', true)),
      );
      final messages = server.sent.last['messages'] as List;
      expect(messages.first, containsPair('role', 'system'));
      expect(messages.last, {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': '{"workout_count":3}',
      });
    },
  );

  test(
    'Ollama takes arguments as an object and results by tool name',
    () async {
      final server = _server([
        jsonEncode({
          'message': {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'function': {
                  'name': 'workouts',
                  'arguments': {'from': '2026-11-16'},
                },
              },
            ],
          },
        }),
        jsonEncode({
          'message': {'role': 'assistant', 'content': '這週 3 次。'},
        }),
      ]);
      final drafter = OllamaDrafter(
        client: server.client,
        readKey: () async => 'k',
        readModel: () => 'gemma',
      );

      expect(await converse(drafter), '這週 3 次。');
      expect(ran.single.$1, 'workouts');
      expect(ran.single.$2, {'from': '2026-11-16'});
      expect(
        (server.sent.first['tools'] as List).single,
        isNot(containsPair('function', containsPair('strict', true))),
      );
      expect((server.sent.last['messages'] as List).last, {
        'role': 'tool',
        'tool_name': 'workouts',
        'content': '{"workout_count":3}',
      });
    },
  );

  test('ChatGPT sends the call and its output back without ids', () async {
    final secrets = MemorySecretStore();
    await secrets.write(
      'ai_key_chatgpt',
      jsonEncode({'client_id': 'oaiapp_1', 'refresh_token': 'r-1'}),
    );
    String stream(List<Map<String, Object?>> events) =>
        events.map((event) => 'data: ${jsonEncode(event)}\n\n').join();
    final server = _server(
      [
        stream([
          {
            'type': 'response.output_item.done',
            'item': {
              'type': 'function_call',
              'id': 'fc_1',
              'call_id': 'call_1',
              'name': 'workouts',
              'arguments': '{"from":"2026-11-16"}',
            },
          },
          {'type': 'response.completed'},
        ]),
        stream([
          {'type': 'response.reasoning_summary_text.delta', 'delta': '數這週的訓練。'},
          {'type': 'response.output_text.delta', 'delta': '這週 3 次。'},
          {'type': 'response.completed'},
        ]),
      ],
      other: (request) => switch (request.url.path) {
        '/api/accounts/oauth/token' => jsonEncode({
          'access_token': 'a-1',
          'refresh_token': 'r-1',
          'expires_in': 3600,
        }),
        _ => null,
      },
    );
    final drafter = ChatGptDrafter(
      client: server.client,
      readModel: () => 'gpt-a',
      secrets: secrets,
      sessionKey: 'ai_key_chatgpt',
      readReasoning: () => AiReasoning.auto,
    );

    final thinking = StringBuffer();
    expect(
      await drafter.converse(
        instructions: 'Answer from the tools.',
        history: const [
          AiTurn(AiSpeaker.user, '上週呢'),
          AiTurn(AiSpeaker.assistant, '上週 2 次。'),
        ],
        message: '這週練了幾次',
        tools: const [_tool],
        runTool: runTool,
        onThinking: thinking.write,
      ),
      '這週 3 次。',
    );
    expect(thinking.toString(), '數這週的訓練。');
    expect(ran.single.$1, 'workouts');
    expect(ran.single.$2, {'from': '2026-11-16'});
    expect(
      (server.sent.first['tools'] as List).single,
      containsPair('strict', true),
    );
    expect(
      server.sent.first['reasoning'],
      containsPair('summary', 'auto'),
      reason: 'the summary is asked for only when it is watched',
    );
    final input = server.sent.last['input'] as List;
    expect(input.sublist(3), [
      {
        'type': 'function_call',
        'call_id': 'call_1',
        'name': 'workouts',
        'arguments': '{"from":"2026-11-16"}',
      },
      {
        'type': 'function_call_output',
        'call_id': 'call_1',
        'output': '{"workout_count":3}',
      },
    ]);
  });

  test('a model that keeps calling tools is stopped', () async {
    final call = jsonEncode({
      'content': [
        {'type': 'tool_use', 'id': 'tu', 'name': 'workouts', 'input': {}},
      ],
    });
    final server = _server(List.filled(CloudDrafter.maxToolRounds, call));
    final drafter = AnthropicDrafter(
      client: server.client,
      readKey: () async => 'k',
      readModel: () => 'claude',
    );

    await expectLater(
      converse(drafter),
      throwsA(
        isA<AiException>().having(
          (e) => e.failure,
          'failure',
          AiFailure.providerError,
        ),
      ),
    );
    expect(ran, hasLength(CloudDrafter.maxToolRounds));
  });

  test('Copilot cannot call tools', () async {
    final drafter = CopilotDrafter(
      client: MockClient((_) async => fail('nothing is sent')),
      readKey: () async => 'k',
      readModel: () => '',
      readClientId: () => 'c',
      readTenant: () => 't',
      saveRefreshToken: (_) async {},
    );

    await expectLater(
      converse(drafter),
      throwsA(
        isA<AiException>().having(
          (e) => e.failure,
          'failure',
          AiFailure.toolsUnsupported,
        ),
      ),
    );
  });
}
