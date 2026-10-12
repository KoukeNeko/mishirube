import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../domain/domain.dart';
import 'cloud_drafter.dart';
import 'food_photo.dart';
import 'meal_drafter.dart';
import 'secret_store.dart';

/// The user's own ChatGPT plan, through OpenAI's Sign in with ChatGPT.
///
/// What a request costs comes out of the plan's included usage, capped
/// per app in ChatGPT's settings, instead of an API key's billing. The
/// sign-in is OAuth with PKCE against a loopback address this app
/// listens on while the browser is open; OpenAI issues the app a client
/// ID of its own on first consent, and only a refresh token is kept.
///
/// The one route its documentation gives is the Responses API at
/// `api.openai.com`, which wants `store: false` and a stream: a chat
/// completion or the endpoint the Codex CLI uses is not that route.
class ChatGptDrafter extends CloudDrafter {
  ChatGptDrafter({
    required super.client,
    required super.readModel,
    required this.secrets,
    required this.sessionKey,
    this.readReasoning = _leaveToModel,
  }) : super(readKey: () => secrets.read(sessionKey));

  static AiReasoning _leaveToModel() => AiReasoning.auto;

  static const _auth = 'auth.openai.com';
  static const _api = 'api.openai.com';
  static final _tokenEndpoint = Uri.https(_auth, '/api/accounts/oauth/token');
  static final _revokeEndpoint = Uri.https(_auth, '/api/accounts/oauth/revoke');
  static final _responsesEndpoint = Uri.https(_api, '/v1/responses');
  static final _modelsEndpoint = Uri.https(_api, '/v1/models');

  /// The client ID a first sign-in registers under; OpenAI answers with
  /// the one the app keeps.
  static const registrationClientId = 'dynamic_agent_client';

  /// Shown to the user on OpenAI's consent page, where they may edit it.
  static const appName = 'MISHIRUBE';

  static const planScope = 'chatgpt.tokens.use.direct';
  static const _scopes =
      'openid profile email offline_access resource.invoke $planScope';
  static const _resource = 'https://api.openai.com/v1';
  static const _callbackPath = '/auth/callback';

  /// How long the browser has to come back.
  static const signInTimeout = Duration(minutes: 5);

  /// Refresh failures that end the session: the user signs in again.
  static const _endedSession = {
    'invalid_grant',
    'invalid_refresh_token',
    'token_expired',
    'refresh_token_expired',
    'refresh_token_invalidated',
    'refresh_token_reused',
  };

  final SecretStore secrets;

  /// Where the session lives in [secrets]: the issued client ID and the
  /// refresh token, as JSON. The host ID is kept beside it.
  final String sessionKey;

  /// How hard the model thinks, as the user set it.
  final AiReasoning Function() readReasoning;

  String get _hostKey => '$sessionKey.host';

  String? _accessToken;
  DateTime? _accessTokenUntil;
  Future<String>? _refreshing;
  String? _firstModel;
  HttpServer? _listener;

  @override
  AiProviderKind get kind => AiProviderKind.chatgpt;

  /// The model the user picked, else the first one the plan lists.
  @override
  Future<String> modelName() async {
    final chosen = readModel();
    if (chosen.isNotEmpty) return chosen;
    return _firstModel ??= switch (await models()) {
      [final first, ...] => first,
      _ => throw const AiException(AiFailure.unavailable),
    };
  }

  /// The models the signed-in plan offers, in the order OpenAI lists
  /// them, which is not alphabetical.
  @override
  Future<List<String>> models() async {
    final body = await send(
      () async => client.get(
        _modelsEndpoint,
        headers: {'Authorization': 'Bearer ${await key()}'},
      ),
    );
    return switch (body) {
      {'models': final List<dynamic> models} => [
        for (final model in models)
          if (model case {'slug': final String slug, 'visibility': 'list'}
              when slug.isNotEmpty)
            slug,
      ],
      _ => unreadable(body),
    };
  }

  /// A token to call OpenAI with, refreshing it when the last one has
  /// run out. Two requests at once share one refresh: each one rotates
  /// the refresh token, so the second would spend a token already used.
  @override
  Future<String> key() async {
    if (_accessToken case final token?
        when _accessTokenUntil?.isAfter(DateTime.now()) ?? false) {
      return token;
    }
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _refresh() async {
    final session = await _readSession();
    if (session == null) throw const AiException(AiFailure.unavailable);
    final Map<String, dynamic> body;
    try {
      body = await send(
        () async => client.post(
          _tokenEndpoint,
          body: {
            'grant_type': 'refresh_token',
            'client_id': session.clientId,
            'refresh_token': session.refreshToken,
            'resource': _resource,
          },
        ),
      );
    } on AiException catch (error) {
      if (_endedSession.contains(_errorCode(error.detail))) {
        await _forget();
        throw AiException(AiFailure.authentication, error.detail);
      }
      rethrow;
    }
    final token = body['access_token'];
    if (token is! String) unreadable(body);
    if (body['refresh_token'] case final String rotated) {
      await _writeSession(session.clientId, rotated);
    }
    return _keepAccessToken(token, body);
  }

  String _keepAccessToken(String token, Map<String, dynamic> body) {
    _accessToken = token;
    final seconds = (body['expires_in'] as num?)?.round() ?? 3600;
    // A minute's margin, so a token does not expire mid-request.
    _accessTokenUntil = DateTime.now().add(Duration(seconds: seconds - 60));
    return token;
  }

  /// Signs in through [launch], which opens the page in a browser and
  /// says whether it could. True once signed in, false when
  /// [cancelSignIn] ended the wait. Throws [AiFailure.authentication]
  /// when the user declined, did not grant the plan, or never came back.
  Future<bool> signIn(Future<bool> Function(Uri url) launch) async {
    final session = await _readSession();
    final clientId = session?.clientId ?? registrationClientId;
    final hostId = await _hostId();
    final verifier = _random(32);
    final state = _random(16);
    final nonce = _random(16);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _listener = server;
    try {
      final redirect = 'http://127.0.0.1:${server.port}$_callbackPath';
      final url = Uri.https(_auth, '/api/accounts/authorize', {
        'client_id': clientId,
        if (session == null) 'agent_name_hint': appName,
        'ext_agent_host_id': hostId,
        'response_type': 'code',
        'redirect_uri': redirect,
        'scope': _scopes,
        'resource': _resource,
        'state': state,
        'nonce': nonce,
        'code_challenge_method': 'S256',
        'code_challenge': base64Url
            .encode(sha256.convert(utf8.encode(verifier)).bytes)
            .replaceAll('=', ''),
      });
      if (!await launch(url)) throw const AiException(AiFailure.unavailable);
      final callback = await _awaitCallback(server);
      if (callback == null) return false;

      if (callback['state'] != state) {
        throw const AiException(AiFailure.authentication, 'state mismatch');
      }
      if (callback['error'] case final error?) {
        throw AiException(AiFailure.authentication, error);
      }
      final code = callback['code'];
      // A registration answers with the client ID it issued; a returning
      // sign-in may leave it out but never swap it.
      final issued = callback['client_id'] ?? session?.clientId;
      if (code == null ||
          issued == null ||
          issued == registrationClientId ||
          (session != null && issued != session.clientId)) {
        throw const AiException(AiFailure.authentication, 'no client ID');
      }

      final body = await send(
        () async => client.post(
          _tokenEndpoint,
          body: {
            'grant_type': 'authorization_code',
            'client_id': issued,
            'code': code,
            'code_verifier': verifier,
            'redirect_uri': redirect,
            'resource': _resource,
          },
        ),
      );
      final scope = body['scope'] ?? callback['scope'];
      if (scope is! String || !scope.split(' ').contains(planScope)) {
        throw const AiException(AiFailure.authentication, 'plan not granted');
      }
      if (body case {
        'access_token': final String token,
        'refresh_token': final String refresh,
        'id_token': final String idToken,
      }) {
        _checkIdentity(idToken, clientId: issued, nonce: nonce);
        await _writeSession(issued, refresh);
        _keepAccessToken(token, body);
        return true;
      }
      return unreadable(body);
    } finally {
      _listener = null;
      await server.close(force: true);
    }
  }

  /// Ends the wait in [signIn], the browser having been closed.
  Future<void> cancelSignIn() async => _listener?.close(force: true);

  /// The query of the browser's return, or null once cancelled. A
  /// request for anything else, like an icon, is turned away.
  Future<Map<String, String>?> _awaitCallback(HttpServer server) async {
    try {
      await for (final request in server.timeout(signInTimeout)) {
        final response = request.response;
        if (request.uri.path != _callbackPath) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
          continue;
        }
        response
          ..headers.contentType = ContentType.html
          ..write(
            '<!doctype html><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width">'
            '<title>$appName</title>'
            '<body style="font:600 20px system-ui;text-align:center;'
            'margin-top:30vh">$appName ✓',
          );
        await response.close();
        return request.uri.queryParameters;
      }
      return null;
    } on TimeoutException {
      throw const AiException(AiFailure.authentication, 'timed out');
    }
  }

  /// The ID token came straight from OpenAI's token endpoint over TLS,
  /// which OpenID Connect takes in place of checking its signature, so
  /// only what the sign-in itself must match is read.
  void _checkIdentity(
    String idToken, {
    required String clientId,
    required String nonce,
  }) {
    final parts = idToken.split('.');
    final Object? claims;
    try {
      claims = parts.length == 3
          ? jsonDecode(
              utf8.decode(base64Url.decode(base64.normalize(parts[1]))),
            )
          : null;
    } on FormatException {
      throw const AiException(AiFailure.authentication, 'unreadable ID token');
    }
    if (claims is! Map<String, dynamic>) {
      throw const AiException(AiFailure.authentication, 'unreadable ID token');
    }
    final audience = claims['aud'];
    final expires = claims['exp'];
    final isValid =
        claims['iss'] == 'https://$_auth' &&
        (audience == clientId ||
            (audience is List && audience.contains(clientId))) &&
        claims['nonce'] == nonce &&
        expires is num &&
        DateTime.fromMillisecondsSinceEpoch(expires.round() * 1000)
            .isAfter(DateTime.now());
    if (!isValid) {
      throw const AiException(AiFailure.authentication, 'ID token mismatch');
    }
  }

  /// Signs out: the refresh token is revoked at OpenAI, and the session
  /// is forgotten here either way. False when OpenAI could not be told,
  /// so the user can disconnect the app in ChatGPT's settings instead.
  Future<bool> signOut() async {
    final session = await _readSession();
    await _forget();
    if (session == null) return true;
    try {
      await send(
        () async => client.post(
          _revokeEndpoint,
          body: {
            'token': session.refreshToken,
            'token_type_hint': 'refresh_token',
            'client_id': session.clientId,
          },
        ),
      );
      return true;
    } on AiException catch (error) {
      // An empty 200 is how it says yes, which is not JSON to [send].
      return error.failure == AiFailure.unreadable && error.detail == '';
    }
  }

  /// The images the plan's model accepts go in as `input_image`; a model
  /// that takes none refuses with an unsupported capability.
  @override
  Future<bool> readsPhotos() async => true;

  @override
  Future<String> chat(
    String instructions,
    String message, {
    FoodPhoto? photo,
    bool search = false,
  }) => _respond(instructions, message, photo: photo);

  @override
  Future<String> streamChat(
    String instructions,
    String message, {
    required ThinkingSink onThinking,
    FoodPhoto? photo,
    bool search = false,
  }) => _respond(instructions, message, photo: photo, onThinking: onThinking);

  Future<String> _respond(
    String instructions,
    String message, {
    FoodPhoto? photo,
    ThinkingSink? onThinking,
  }) async {
    try {
      return await readStream(() async {
        final request = jsonRequest(
          _responsesEndpoint,
          {
            'Authorization': 'Bearer ${await key()}',
            'Content-Type': 'application/json',
          },
          {
            'model': await modelName(),
            'instructions': instructions,
            'input': [
              {
                'role': 'user',
                'content': photo == null
                    ? message
                    : [
                        {'type': 'input_text', 'text': message},
                        {'type': 'input_image', 'image_url': photo.dataUrl},
                      ],
              },
            ],
            'store': false,
            'stream': true,
            if (readReasoning() != AiReasoning.auto || onThinking != null)
              'reasoning': {
                if (readReasoning() != AiReasoning.auto)
                  'effort': readReasoning().name,
                if (onThinking != null) 'summary': 'auto',
              },
          },
        );
        final answer = StringBuffer();
        var isComplete = false;
        await for (final event in sse(request)) {
          switch (event['type']) {
            case 'response.output_text.delta':
              if (event['delta'] case final String text) answer.write(text);
            case 'response.reasoning_summary_text.delta':
              if (event['delta'] case final String text) onThinking?.call(text);
            case 'response.completed':
              isComplete = true;
            case 'response.failed':
              final error = switch (event) {
                {'response': {'error': final Map<String, dynamic> error}} =>
                  error,
                _ => const <String, dynamic>{},
              };
              throw AiException(
                _failureOf(error['code']) ?? AiFailure.providerError,
                jsonEncode(error),
              );
            case 'response.incomplete':
              unreadable(event);
          }
        }
        // A stream that stops before `response.completed` is a failure,
        // whatever text it had got to.
        if (!isComplete) {
          throw const AiException(AiFailure.network, 'the stream ended early');
        }
        return answer.isEmpty ? unreadable('empty reply') : '$answer';
      });
    } on AiException catch (error) {
      if (photo != null &&
          _errorCode(error.detail) ==
              'subscription_sharing_unsupported_capability') {
        throw AiException(AiFailure.photoUnsupported, error.detail);
      }
      rethrow;
    }
  }

  /// The plan's own refusals, which name what is wrong in `code` where
  /// the status alone says little.
  @override
  Never throwForStatus(int status, String body) {
    if (_failureOf(_errorCode(body)) case final failure?) {
      throw AiException(failure, body);
    }
    super.throwForStatus(status, body);
  }

  static AiFailure? _failureOf(Object? code) => switch (code) {
    'subscription_sharing_usage_limit_exceeded' => AiFailure.rateLimited,
    'subscription_sharing_user_not_eligible' ||
    'subscription_sharing_invalid_user' ||
    'chatpass_v2_scope_not_authorized' ||
    'chatpass_v2_invalid_authorization_context' => AiFailure.authentication,
    _ => null,
  };

  /// The error code in a response body, whether it sits in an `error`
  /// object, is the `error` itself (OAuth's way) or stands alone.
  static String? _errorCode(String? body) {
    try {
      return switch (jsonDecode(body ?? '')) {
        {'error': {'code': final String code}} ||
        {'error': final String code} ||
        {'code': final String code} => code,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  Future<({String clientId, String refreshToken})?> _readSession() async {
    final stored = await secrets.read(sessionKey);
    if (stored == null) return null;
    return switch (jsonDecode(stored)) {
      {'client_id': final String id, 'refresh_token': final String token} => (
        clientId: id,
        refreshToken: token,
      ),
      _ => null,
    };
  }

  Future<void> _writeSession(String clientId, String refreshToken) =>
      secrets.write(
        sessionKey,
        jsonEncode({'client_id': clientId, 'refresh_token': refreshToken}),
      );

  Future<void> _forget() async {
    _accessToken = null;
    _accessTokenUntil = null;
    await secrets.delete(sessionKey);
  }

  /// Tells OpenAI which installation this is: a `urn:uuid:` URI, one of
  /// the forms it accepts, made once and kept. It stays out of the
  /// database so a restored backup does not hand one device's ID to
  /// another. A stored value of any other form was refused at sign-in,
  /// so it never identified this device and is replaced.
  Future<String> _hostId() async {
    final existing = await secrets.read(_hostKey);
    if (existing != null && _hostIdForm.hasMatch(existing)) return existing;
    final id = _uuidUrn();
    await secrets.write(_hostKey, id);
    return id;
  }

  static final _hostIdForm = RegExp(
    r'^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// A random (version 4) UUID as a URN.
  static String _uuidUrn() {
    final random = Random.secure();
    final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
    bytes[6] = bytes[6] & 0x0f | 0x40;
    bytes[8] = bytes[8] & 0x3f | 0x80;
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return 'urn:uuid:${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// [bytes] random bytes as base64url without padding: what PKCE and a
  /// `state` are made of.
  static String _random(int bytes) {
    final random = Random.secure();
    return base64Url
        .encode([for (var i = 0; i < bytes; i++) random.nextInt(256)])
        .replaceAll('=', '');
  }
}
