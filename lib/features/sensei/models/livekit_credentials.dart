class LiveKitCredentials {
  final String url;
  final String token;
  final String? roomName;
  final String? agentIdentity;
  final Map<String, dynamic>? dispatch;

  const LiveKitCredentials({
    required this.url,
    required this.token,
    this.roomName,
    this.agentIdentity,
    this.dispatch,
  });

  factory LiveKitCredentials.fromJson(Map<String, dynamic> json) {
    // Some token endpoints nest credentials within a "data" or "session" object.
    final Map<String, dynamic> normalized = _normalizePayload(json);

    final url = (normalized['url'] ??
        normalized['livekitUrl'] ??
        normalized['wsUrl']) as String?;
    final token = (normalized['token'] ?? normalized['accessToken']) as String?;

    if (url == null || token == null) {
      throw ArgumentError(
        'LiveKit credentials payload must include "url" and "token" fields.',
      );
    }

    return LiveKitCredentials(
      url: url,
      token: token,
      roomName: normalized['roomName'] as String?,
      agentIdentity: normalized['identity'] as String? ??
          normalized['agentIdentity'] as String?,
      dispatch: normalized['dispatch'] is Map<String, dynamic>
          ? normalized['dispatch'] as Map<String, dynamic>
          : null,
    );
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> json) {
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      return _normalizePayload(json['data'] as Map<String, dynamic>);
    }

    if (json.containsKey('session') &&
        json['session'] is Map<String, dynamic>) {
      return _normalizePayload(json['session'] as Map<String, dynamic>);
    }

    if (json.containsKey('credentials') &&
        json['credentials'] is Map<String, dynamic>) {
      return _normalizePayload(json['credentials'] as Map<String, dynamic>);
    }

    return json;
  }
}
