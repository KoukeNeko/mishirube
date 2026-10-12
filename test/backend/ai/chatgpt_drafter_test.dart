import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/backend/ai/chatgpt_drafter.dart';
import 'package:mishirube/backend/ai/food_photo.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/domain/domain.dart';

const _sessionKey = 'ai_key_chatgpt';
const _hostKey = '$_sessionKey.host';

const _answer = '{"items":[{"name":"蛋餅","kcal":250}]}';

void main() {
  late MemorySecretStore secrets;

  setUp(() => secrets = MemorySecretStore());

  ChatGptDrafter drafter(
    http.Client client, {
    String model = '',
    AiReasoning reasoning = AiReasoning.auto,
  }) => ChatGptDrafter(
    client: client,
    readModel: () => model,
    secrets: secrets,
    sessionKey: _sessionKey,
    readReasoning: () => reasoning,
  );

  Future<void> signedIn({String refresh = 'r-1'}) => secrets.write(
    _sessionKey,
    jsonEncode({'client_id': 'oaiapp_1', 'refresh_token': refresh}),
  );

  Future<Map<String, dynamic>> session() async =>
      jsonDecode((await secrets.read(_sessionKey))!) as Map<String, dynamic>;

  group('signing in', () {
    /// What the browser does when the user consents: a visit to the
    /// loopback address the app gave. The test's own HTTP client is
    /// blocked, so it speaks HTTP over a socket.
    Future<void> visit(Uri url) async {
      final socket = await Socket.connect(url.host, url.port);
      socket.write(
        'GET ${url.path}?${url.query} HTTP/1.1\r\n'
        'Host: ${url.authority}\r\nConnection: close\r\n\r\n',
      );
      await socket.flush();
      await socket.drain<void>();
      socket.destroy();
    }

    String idToken({
      required String nonce,
      String audience = 'oaiapp_1',
      String issuer = 'https://auth.openai.com',
      int? expires,
    }) {
      String part(Map<String, Object?> json) =>
          base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
      return [
        part({'alg': 'RS256'}),
        part({
          'iss': issuer,
          'aud': audience,
          'nonce': nonce,
          'exp':
              expires ??
              DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
        }),
        'signature',
      ].join('.');
    }

    test('registers, then keeps the client OpenAI issued and the refresh '
        'token', () async {
      late Uri authorization;
      final exchanges = <Map<String, String>>[];
      final client = MockClient((request) async {
        exchanges.add(request.bodyFields);
        return http.Response(
          jsonEncode({
            'access_token': 'a-1',
            'refresh_token': 'r-1',
            'id_token': idToken(nonce: authorization.queryParameters['nonce']!),
            'expires_in': 3600,
            'scope': 'openid offline_access chatgpt.tokens.use.direct',
          }),
          200,
        );
      });
      final chatgpt = drafter(client);

      final isSignedIn = await chatgpt.signIn((url) async {
        authorization = url;
        final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
        unawaited(
          visit(
            redirect.replace(
              queryParameters: {
                'code': 'c-1',
                'state': url.queryParameters['state']!,
                'client_id': 'oaiapp_1',
              },
            ),
          ),
        );
        return true;
      });

      expect(isSignedIn, isTrue);
      final query = authorization.queryParameters;
      expect(authorization.host, 'auth.openai.com');
      expect(authorization.path, '/api/accounts/authorize');
      expect(query['client_id'], 'dynamic_agent_client');
      expect(query['agent_name_hint'], 'MISHIRUBE');
      expect(query['response_type'], 'code');
      expect(query['code_challenge_method'], 'S256');
      expect(query['resource'], 'https://api.openai.com/v1');
      expect(
        query['scope']!.split(' '),
        containsAll([
          'openid',
          'profile',
          'email',
          'offline_access',
          'resource.invoke',
          'chatgpt.tokens.use.direct',
        ]),
      );
      expect(
        query['redirect_uri'],
        matches(RegExp(r'^http://127\.0\.0\.1:\d+/auth/callback$')),
        reason: 'a loopback address, never `localhost`',
      );

      final exchange = exchanges.single;
      expect(exchange['grant_type'], 'authorization_code');
      expect(exchange['client_id'], 'oaiapp_1', reason: 'the issued one');
      expect(exchange['code'], 'c-1');
      expect(exchange['redirect_uri'], query['redirect_uri']);
      expect(exchange['resource'], 'https://api.openai.com/v1');
      expect(
        exchange['code_verifier'],
        isNotEmpty,
        reason: 'the proof for the challenge sent first',
      );
      expect(exchange, isNot(contains('client_secret')));

      expect(await session(), {
        'client_id': 'oaiapp_1',
        'refresh_token': 'r-1',
      });
      expect(await secrets.read(_hostKey), query['ext_agent_host_id']);
      expect(
        query['ext_agent_host_id'],
        matches(
          RegExp(
            r'^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}'
            r'-[0-9a-f]{12}$',
          ),
        ),
        reason: 'OpenAI refuses a host ID that is not one of its forms',
      );
      expect(await chatgpt.availability(), AiAvailability.available);
    });

    const host = 'urn:uuid:3f1c9a52-7d0e-4b86-9a1d-5e2f60c4b7a8';

    test('a returning sign-in uses the issued client, and this host', () async {
      await signedIn();
      await secrets.write(_hostKey, host);
      late Uri authorization;
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'access_token': 'a-2',
            'refresh_token': 'r-2',
            'id_token': idToken(nonce: authorization.queryParameters['nonce']!),
            'scope': 'openid chatgpt.tokens.use.direct',
          }),
          200,
        ),
      );

      await drafter(client).signIn((url) async {
        authorization = url;
        unawaited(
          visit(
            Uri.parse(url.queryParameters['redirect_uri']!).replace(
              // A returning sign-in may leave the client ID out.
              queryParameters: {
                'code': 'c-2',
                'state': url.queryParameters['state']!,
              },
            ),
          ),
        );
        return true;
      });

      final query = authorization.queryParameters;
      expect(query['client_id'], 'oaiapp_1');
      expect(query, isNot(contains('agent_name_hint')));
      expect(query['ext_agent_host_id'], host);
      expect((await session())['refresh_token'], 'r-2');
    });

    test('a stored host ID OpenAI would refuse is replaced before it is '
        'sent', () async {
      // What the first build made: bare base64, which OpenAI answers
      // with `invalid_authorize_request` on `ext_agent_host_id`.
      await secrets.write(_hostKey, 'Zm9vYmFyYmF6cXV4');
      late Uri authorization;

      await expectLater(
        drafter(MockClient((_) async => http.Response('', 500)))
            .signIn((url) async {
              authorization = url;
              return false;
            }),
        throwsA(isA<AiException>()),
      );

      final sent = authorization.queryParameters['ext_agent_host_id'];
      expect(sent, startsWith('urn:uuid:'));
      expect(await secrets.read(_hostKey), sent);
    });

    /// A sign-in whose browser comes back with [callback], where [grant]
    /// answers the code exchange.
    Future<AiException> failedSignIn({
      required Map<String, String> Function(String state) callback,
      String scope = 'openid chatgpt.tokens.use.direct',
      String? Function(String nonce)? token,
    }) async {
      late Uri authorization;
      var exchanges = 0;
      final client = MockClient((request) async {
        exchanges++;
        final nonce = authorization.queryParameters['nonce']!;
        return http.Response(
          jsonEncode({
            'access_token': 'a-1',
            'refresh_token': 'r-1',
            'id_token': token?.call(nonce) ?? idToken(nonce: nonce),
            'scope': scope,
          }),
          200,
        );
      });
      final error = await drafter(client)
          .signIn((url) async {
            authorization = url;
            unawaited(
              visit(
                Uri.parse(url.queryParameters['redirect_uri']!).replace(
                  queryParameters: callback(url.queryParameters['state']!),
                ),
              ),
            );
            return true;
          })
          .then<AiException?>(
            (_) => null,
            onError: (Object e) => e as AiException,
          );
      expect(await secrets.read(_sessionKey), isNull, reason: 'nothing kept');
      expect(error, isNotNull);
      expect(error!.failure, AiFailure.authentication);
      // A refusal before the exchange sends no code to OpenAI at all.
      if (callback('s').containsKey('error')) expect(exchanges, 0);
      return error;
    }

    test('a plan the user did not grant is not a sign-in', () async {
      await failedSignIn(
        scope: 'openid profile email',
        callback: (state) => {
          'code': 'c-1',
          'state': state,
          'client_id': 'oaiapp_1',
        },
      );
    });

    test('a callback for another attempt is refused', () async {
      await failedSignIn(
        callback: (_) => {
          'code': 'c-1',
          'state': 'not-the-state',
          'client_id': 'oaiapp_1',
        },
      );
    });

    test('a declined consent is not exchanged', () async {
      final error = await failedSignIn(
        callback: (state) => {'error': 'access_denied', 'state': state},
      );
      expect(error.detail, 'access_denied');
    });

    test('an ID token for another nonce or client is refused', () async {
      Map<String, String> consent(String state) => {
        'code': 'c-1',
        'state': state,
        'client_id': 'oaiapp_1',
      };
      await failedSignIn(
        callback: consent,
        token: (_) => idToken(nonce: 'someone-elses'),
      );
      await failedSignIn(
        callback: consent,
        token: (nonce) => idToken(nonce: nonce, audience: 'oaiapp_2'),
      );
      await failedSignIn(
        callback: consent,
        token: (nonce) => idToken(nonce: nonce, expires: 1),
      );
    });

    test('ending the wait ends the sign-in without signing in', () async {
      final chatgpt = drafter(MockClient((_) async => http.Response('', 500)));

      final isSignedIn = await chatgpt.signIn((_) async {
        unawaited(Future(chatgpt.cancelSignIn));
        return true;
      });

      expect(isSignedIn, isFalse);
      expect(await secrets.read(_sessionKey), isNull);
    });

    test('a browser that will not open is unavailable', () async {
      await expectLater(
        drafter(MockClient((_) async => http.Response('', 500)))
            .signIn((_) async => false),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.unavailable,
          ),
        ),
      );
    });
  });

  group('asking', () {
    /// What OpenAI streams: one `data:` line per event.
    String stream(List<Map<String, Object?>> events) =>
        events.map((event) => 'data: ${jsonEncode(event)}\n\n').join();

    Map<String, Object?> delta(String text) => {
      'type': 'response.output_text.delta',
      'delta': text,
    };

    const completed = {'type': 'response.completed'};

    /// Answers the token refresh, the model list and the response,
    /// remembering what was sent where.
    ({http.Client client, List<http.Request> requests}) openai({
      List<Map<String, Object?>>? events,
      int responseStatus = 200,
      String? responseBody,
    }) {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return switch (request.url.path) {
          '/api/accounts/oauth/token' => http.Response(
            jsonEncode({
              'access_token': 'a-${requests.length}',
              'refresh_token': 'r-rotated',
              'expires_in': 3600,
            }),
            200,
          ),
          '/v1/models' => http.Response(
            jsonEncode({
              'models': [
                {'slug': 'hidden-1', 'display_name': 'H', 'visibility': 'hide'},
                {
                  'slug': 'gpt-first',
                  'display_name': 'F',
                  'visibility': 'list',
                },
                {'slug': 'gpt-a', 'display_name': 'A', 'visibility': 'list'},
              ],
            }),
            200,
          ),
          // Bytes, since the answer is Chinese and a string response is
          // Latin-1.
          _ => http.Response.bytes(
            utf8.encode(
              responseBody ??
                  stream(
                    events ??
                        [
                          delta(_answer.substring(0, 12)),
                          delta(_answer.substring(12)),
                          completed,
                        ],
                  ),
            ),
            responseStatus,
          ),
        };
      });
      return (client: client, requests: requests);
    }

    Future<AiException> failure(Future<Object?> request) async {
      try {
        await request;
      } on AiException catch (error) {
        return error;
      }
      fail('expected an AiException');
    }

    test('refreshes, takes the first listed model, and sends only what the '
        'plan route allows', () async {
      await signedIn();
      final server = openai();

      final draft = await drafter(server.client).draftMeal('早餐 蛋餅');

      expect(draft.items.single.name, '蛋餅');
      expect(draft.provider, AiProviderKind.chatgpt);
      expect(
        draft.model,
        'gpt-first',
        reason: 'the first model listed for the plan, in the order it gave',
      );
      expect(server.requests.map((request) => request.url.path), [
        '/api/accounts/oauth/token',
        '/v1/models',
        '/v1/responses',
      ]);

      final refresh = server.requests.first.bodyFields;
      expect(refresh['grant_type'], 'refresh_token');
      expect(refresh['client_id'], 'oaiapp_1');
      expect(refresh['refresh_token'], 'r-1');
      expect(refresh['resource'], 'https://api.openai.com/v1');
      expect(refresh, isNot(contains('scope')), reason: 'keeps the grant');
      expect((await session())['refresh_token'], 'r-rotated');

      final request = server.requests.last;
      expect(request.url.host, 'api.openai.com');
      expect(request.headers['Authorization'], 'Bearer a-1');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-first');
      expect(body['store'], isFalse);
      expect(body['stream'], isTrue);
      expect(body['instructions'], isNotEmpty);
      expect(body['input'], [
        {'role': 'user', 'content': '早餐 蛋餅'},
      ]);
      for (final unsupported in [
        'previous_response_id',
        'temperature',
        'max_output_tokens',
        'tools',
      ]) {
        expect(body, isNot(contains(unsupported)));
      }
    });

    test('the model the user picked is the one asked, and one refresh serves '
        'every request at once', () async {
      await signedIn();
      final server = openai();
      final chatgpt = drafter(server.client, model: 'gpt-a');

      await Future.wait([
        chatgpt.draftMeal('早餐 蛋餅'),
        chatgpt.draftMeal('午餐 便當'),
      ]);
      await chatgpt.draftMeal('晚餐 麵');

      final paths = server.requests.map((request) => request.url.path);
      expect(
        paths.where((path) => path.endsWith('/token')),
        hasLength(1),
        reason:
            'each refresh rotates the token, so a second one would '
            'spend the old token',
      );
      expect(paths, isNot(contains('/v1/models')));
      for (final request in server.requests.where(
        (request) => request.url.path == '/v1/responses',
      )) {
        expect(
          (jsonDecode(request.body) as Map<String, dynamic>)['model'],
          'gpt-a',
        );
      }
    });

    test('sends a thinking level only when the user chose one', () async {
      await signedIn();
      Future<Object?> reasoningSent({
        AiReasoning level = AiReasoning.auto,
        bool watched = false,
      }) async {
        final server = openai();
        await drafter(
          server.client,
          model: 'gpt-a',
          reasoning: level,
        ).draftMeal('早餐 蛋餅', onThinking: watched ? (_) {} : null);
        final body =
            jsonDecode(server.requests.last.body) as Map<String, dynamic>;
        return body['reasoning'];
      }

      expect(await reasoningSent(), isNull, reason: 'left to the model');
      expect(await reasoningSent(level: AiReasoning.low), {'effort': 'low'});
      expect(await reasoningSent(level: AiReasoning.medium), {
        'effort': 'medium',
      });
      expect(await reasoningSent(level: AiReasoning.high, watched: true), {
        'effort': 'high',
        'summary': 'auto',
      });
    });

    test('lists the models of the plan, hidden ones left out', () async {
      await signedIn();

      expect(await drafter(openai().client).models(), ['gpt-first', 'gpt-a']);
    });

    test('streams the reasoning summary to whoever watches', () async {
      await signedIn();
      final server = openai(
        events: [
          {'type': 'response.reasoning_summary_text.delta', 'delta': '蛋餅'},
          delta(_answer),
          completed,
        ],
      );
      final thinking = <String>[];

      final draft = await drafter(
        server.client,
        model: 'gpt-a',
      ).draftMeal('早餐 蛋餅', onThinking: thinking.add);

      expect(thinking, ['蛋餅']);
      expect(draft.items.single.name, '蛋餅');
      final body =
          jsonDecode(server.requests.last.body) as Map<String, dynamic>;
      expect(body['reasoning'], {'summary': 'auto'});
    });

    test(
      'a plan used up is rate limited, in a status or in the stream',
      () async {
        await signedIn();
        const code = 'subscription_sharing_usage_limit_exceeded';

        final byStatus = await failure(
          drafter(
            openai(
              responseStatus: 429,
              responseBody: jsonEncode({
                'error': {'code': code},
              }),
            ).client,
            model: 'gpt-a',
          ).chat('i', 'm'),
        );
        final inStream = await failure(
          drafter(
            openai(
              events: [
                delta('{'),
                {
                  'type': 'response.failed',
                  'response': {
                    'error': {'code': code, 'message': 'used up'},
                  },
                },
              ],
            ).client,
            model: 'gpt-a',
          ).chat('i', 'm'),
        );

        expect(byStatus.failure, AiFailure.rateLimited);
        expect(inStream.failure, AiFailure.rateLimited);
      },
    );

    test(
      'an account the plan is not open to is an authentication failure',
      () async {
        await signedIn();

        final error = await failure(
          drafter(
            openai(
              responseStatus: 403,
              responseBody: jsonEncode({
                'error': {'code': 'subscription_sharing_user_not_eligible'},
              }),
            ).client,
            model: 'gpt-a',
          ).chat('i', 'm'),
        );

        expect(error.failure, AiFailure.authentication);
      },
    );

    test('a stream that stops before it completes is a failure', () async {
      await signedIn();

      final error = await failure(
        drafter(
          openai(events: [delta('{"items":')]).client,
          model: 'gpt-a',
        ).chat('i', 'm'),
      );

      expect(error.failure, AiFailure.network);
    });

    group('a photo', () {
      final photo = FoodPhoto(
        path: 'meal.jpg',
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]),
        mimeType: 'image/jpeg',
      );

      test('goes in as an input image beside the text', () async {
        await signedIn();
        final server = openai(
          events: [delta('{"items":[{"name":"蛋餅","kcal":250}]}'), completed],
        );

        expect(
          await drafter(server.client, model: 'gpt-a').readsPhotos(),
          isTrue,
        );
        await drafter(server.client, model: 'gpt-a').draftPhoto(photo);

        final body =
            jsonDecode(server.requests.last.body) as Map<String, dynamic>;
        final content =
            ((body['input'] as List).single as Map)['content'] as List;
        expect(content.first, containsPair('type', 'input_text'));
        expect(content.last, {
          'type': 'input_image',
          'image_url': photo.dataUrl,
        });
      });

      test('a model that cannot see it says so', () async {
        await signedIn();

        final error = await failure(
          drafter(
            openai(
              responseStatus: 400,
              responseBody: jsonEncode({
                'error': {
                  'code': 'subscription_sharing_unsupported_capability',
                  'param': 'input',
                },
              }),
            ).client,
            model: 'gpt-a',
          ).draftPhoto(photo),
        );

        expect(error.failure, AiFailure.photoUnsupported);
      });
    });
  });

  group('a session', () {
    test('without a sign-in asks for one and sends nothing', () async {
      var requests = 0;
      final chatgpt = drafter(
        MockClient((_) async {
          requests++;
          return http.Response('', 200);
        }),
      );

      expect(await chatgpt.availability(), AiAvailability.needsKey);
      await expectLater(
        chatgpt.draftMeal('蛋餅'),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.unavailable,
          ),
        ),
      );
      expect(requests, 0);
    });

    test(
      'whose refresh token OpenAI ended is signed out, not retried',
      () async {
        await signedIn();
        final chatgpt = drafter(
          MockClient(
            (_) async => http.Response(
              jsonEncode({'error': 'refresh_token_reused'}),
              400,
            ),
          ),
          model: 'gpt-a',
        );

        await expectLater(
          chatgpt.chat('i', 'm'),
          throwsA(
            isA<AiException>().having(
              (e) => e.failure,
              'failure',
              AiFailure.authentication,
            ),
          ),
        );

        expect(await secrets.read(_sessionKey), isNull);
        expect(await chatgpt.availability(), AiAvailability.needsKey);
      },
    );

    test('is kept through a refresh that failed for another reason', () async {
      await signedIn();
      final chatgpt = drafter(
        MockClient((_) async => http.Response('down', 503)),
        model: 'gpt-a',
      );

      await expectLater(
        chatgpt.chat('i', 'm'),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.providerError,
          ),
        ),
      );

      expect(await secrets.read(_sessionKey), isNotNull);
    });

    test('signing out revokes the refresh token and forgets it', () async {
      await signedIn();
      late http.Request sent;
      final chatgpt = drafter(
        MockClient((request) async {
          sent = request;
          return http.Response('', 200);
        }),
      );

      expect(await chatgpt.signOut(), isTrue);

      expect(sent.url.path, '/api/accounts/oauth/revoke');
      expect(sent.bodyFields, {
        'token': 'r-1',
        'token_type_hint': 'refresh_token',
        'client_id': 'oaiapp_1',
      });
      expect(await secrets.read(_sessionKey), isNull);
    });

    test('signing out forgets it even when OpenAI cannot be told', () async {
      await signedIn();
      final chatgpt = drafter(
        MockClient((_) async => http.Response('down', 503)),
      );

      expect(await chatgpt.signOut(), isFalse);

      expect(await secrets.read(_sessionKey), isNull);
    });
  });
}
