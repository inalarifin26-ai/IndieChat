/// One external connector (Google Calendar, Gmail, ...). Mirrors the
/// backend's `serialize()` shape in lib/connectors/googleOAuthBase.js.
class Connector {
  final String provider;
  final bool connected;
  final bool configured; // false = the server admin hasn't set up OAuth credentials for this provider
  final String? scope;
  final DateTime? connectedAt;
  final DateTime? expiresAt;
  final bool hasRefreshToken;

  Connector({
    required this.provider,
    required this.connected,
    required this.configured,
    this.scope,
    this.connectedAt,
    this.expiresAt,
    this.hasRefreshToken = false,
  });

  factory Connector.fromApi(Map<String, dynamic> json) => Connector(
        provider: json['provider'] as String,
        connected: json['connected'] as bool? ?? false,
        configured: json['configured'] as bool? ?? true, // omitted by the API once connected — assume true
        scope: json['scope'] as String?,
        connectedAt: json['connectedAt'] == null ? null : DateTime.tryParse(json['connectedAt'].toString()),
        expiresAt: json['expiresAt'] == null ? null : DateTime.tryParse(json['expiresAt'].toString()),
        hasRefreshToken: json['hasRefreshToken'] as bool? ?? false,
      );

  String get displayName {
    switch (provider) {
      case 'google_calendar':
        return 'Google Calendar';
      case 'gmail':
        return 'Gmail';
      case 'google_drive':
        return 'Google Drive';
      default:
        return provider;
    }
  }

  String get subtitle {
    if (!configured) return 'Not available on this server yet';
    if (!connected) return 'Not connected';
    switch (provider) {
      case 'google_calendar':
        return 'Read-only — used by Personal Assistant to read your calendar';
      case 'gmail':
        return 'Read-only — used by Personal Assistant to summarize unread emails';
      case 'google_drive':
        return 'Read-only — list your recent files';
      default:
        return 'Connected';
    }
  }
}
