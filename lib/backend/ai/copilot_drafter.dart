import 'dart:convert';

import '../../domain/domain.dart';
import 'cloud_drafter.dart';
import 'food_photo.dart';

/// What the user has to do to sign in: type this code on that page.
class DeviceCodePrompt {
  const DeviceCodePrompt({
    required this.userCode,
    required this.verificationUri,
    required this.deviceCode,
    required this.interval,
    required this.expiresIn,
  });

  final String userCode;
  final String verificationUri;

  /// The app's half of the pairing, which it polls with.
  final String deviceCode;
  final Duration interval;
  final Duration expiresIn;
}

/// Microsoft 365 Copilot, through the Chat API in Microsoft Graph.
///
/// The only Copilot an app outside an editor may call: GitHub Copilot
/// has no public inference API, and the projects that pretend otherwise
/// drive its internal endpoints against GitHub's terms.
///
/// It is not a key but a sign-in: the user signs in to their work or
/// school account with a device code, and the refresh token is what the
/// app keeps. It needs a Microsoft 365 Copilot licence and an app
/// registration of the user's own, and the API is Microsoft's `beta`.
class CopilotDrafter extends CloudDrafter {
  CopilotDrafter({
    required super.client,
    required super.readKey,
    required super.readModel,
    required this.readClientId,
    required this.readTenant,
    required this.saveRefreshToken,
  });

  /// Everything the Chat API's documentation requires, and a refresh
  /// token so signing in is not a daily chore.
  static const scopes =
      'https://graph.microsoft.com/Sites.Read.All '
      'https://graph.microsoft.com/Mail.Read '
      'https://graph.microsoft.com/People.Read.All '
      'https://graph.microsoft.com/OnlineMeetingTranscript.Read.All '
      'https://graph.microsoft.com/Chat.Read '
      'https://graph.microsoft.com/ChannelMessage.Read.All '
      'https://graph.microsoft.com/ExternalItem.Read.All '
      'offline_access';

  static const graph = 'graph.microsoft.com';
  static const login = 'login.microsoftonline.com';

  final String Function() readClientId;
  final String Function() readTenant;

  /// Keeps the refresh token where keys live, never in the database.
  final Future<void> Function(String token) saveRefreshToken;

  /// The signed-in token, while it lasts.
  String? _accessToken;
  DateTime? _accessTokenUntil;

  @override
  AiProviderKind get kind => AiProviderKind.microsoftCopilot;

  /// Copilot answers as itself; there is no model to choose.
  @override
  Future<String> modelName() async => 'Microsoft 365 Copilot';

  @override
  Future<List<String>> models() async => const [];

  @override
  Future<AiAvailability> availability() async =>
      readClientId().trim().isEmpty || (await readKey())?.isNotEmpty != true
      ? AiAvailability.needsKey
      : AiAvailability.available;

  Uri _loginAt(String path) => Uri.https(
    login,
    '/${readTenant().trim().isEmpty ? 'organizations' : readTenant().trim()}/oauth2/v2.0/$path',
  );

  /// Asks Microsoft for a code for the user to type on their own device.
  Future<DeviceCodePrompt> startSignIn() async {
    final clientId = readClientId().trim();
    if (clientId.isEmpty) throw const AiException(AiFailure.unavailable);
    final body = await send(
      () async => client.post(
        _loginAt('devicecode'),
        body: {'client_id': clientId, 'scope': scopes},
      ),
    );
    return switch (body) {
      {
        'device_code': final String deviceCode,
        'user_code': final String userCode,
        'verification_uri': final String uri,
      } =>
        DeviceCodePrompt(
          userCode: userCode,
          verificationUri: uri,
          deviceCode: deviceCode,
          interval: Duration(seconds: (body['interval'] as num?)?.round() ?? 5),
          expiresIn: Duration(
            seconds: (body['expires_in'] as num?)?.round() ?? 900,
          ),
        ),
      _ => unreadable(body),
    };
  }

  /// Waits for the user to finish signing in, then keeps the refresh
  /// token. Throws [AiFailure.authentication] when they declined or the
  /// code ran out.
  Future<void> finishSignIn(
    DeviceCodePrompt prompt, {
    Future<void> Function(Duration) wait = Future.delayed,
  }) async {
    final deadline = DateTime.now().add(prompt.expiresIn);
    var interval = prompt.interval;
    while (DateTime.now().isBefore(deadline)) {
      await wait(interval);
      final response = await client.post(
        _loginAt('token'),
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': readClientId().trim(),
          'device_code': prompt.deviceCode,
        },
      );
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) unreadable(response.body);
      if (body case {'refresh_token': final String refresh}) {
        await saveRefreshToken(refresh);
        _keepAccessToken(body);
        return;
      }
      switch (body['error']) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += const Duration(seconds: 5);
        default:
          throw AiException(AiFailure.authentication, '${body['error']}');
      }
    }
    throw const AiException(AiFailure.authentication, 'the code expired');
  }

  void _keepAccessToken(Map<String, dynamic> body) {
    if (body case {'access_token': final String token}) {
      _accessToken = token;
      final seconds = (body['expires_in'] as num?)?.round() ?? 3600;
      // A minute's margin, so a token does not expire mid-request.
      _accessTokenUntil = DateTime.now().add(Duration(seconds: seconds - 60));
    }
  }

  /// A token to call Graph with, refreshing the signed-in session when
  /// the last one has run out.
  @override
  Future<String> key() async {
    if (_accessToken case final token?
        when _accessTokenUntil?.isAfter(DateTime.now()) ?? false) {
      return token;
    }
    final refresh = await readKey();
    if (refresh == null || refresh.isEmpty) {
      throw const AiException(AiFailure.unavailable);
    }
    final body = await send(
      () async => client.post(
        _loginAt('token'),
        body: {
          'grant_type': 'refresh_token',
          'client_id': readClientId().trim(),
          'refresh_token': refresh,
          'scope': scopes,
        },
      ),
    );
    if (body case {'refresh_token': final String rotated}) {
      await saveRefreshToken(rotated);
    }
    _keepAccessToken(body);
    return _accessToken ?? unreadable(body);
  }

  /// Copilot's chat takes text only: no image goes in a message.
  @override
  Future<bool> readsPhotos() async => false;

  /// One conversation per request: the app asks one question at a time,
  /// and a fresh conversation carries nothing from the last one. A photo
  /// cannot be sent at all.
  @override
  Future<String> chat(
    String instructions,
    String message, {
    FoodPhoto? photo,
  }) async {
    if (photo != null) throw const AiException(AiFailure.photoUnsupported);
    final token = await key();
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final conversation = await send(
      () async => client.post(
        Uri.https(graph, '/beta/copilot/conversations'),
        headers: headers,
        body: '{}',
      ),
    );
    final id = switch (conversation) {
      {'id': final String id} => id,
      _ => unreadable(conversation),
    };
    final answer = await send(
      () async => client.post(
        Uri.https(graph, '/beta/copilot/conversations/$id/chat'),
        headers: headers,
        // Copilot takes no system message, so the instructions lead.
        body: jsonEncode({
          'message': {'text': '$instructions\n\n$message'},
          'locationHint': {'timeZone': 'Asia/Taipei'},
        }),
      ),
    );
    return switch (answer) {
      {'messages': final List<dynamic> messages} when messages.isNotEmpty =>
        switch (messages.last) {
          {'text': final String text} => text,
          _ => unreadable(answer),
        },
      _ => unreadable(answer),
    };
  }
}
