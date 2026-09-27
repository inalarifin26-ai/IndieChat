import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base URL of the Indie backend.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://localhost:4000
///
/// Defaults to 10.0.2.2, which is how the Android emulator reaches your
/// host machine's localhost. On iOS simulator use `http://localhost:4000`;
/// on a physical device use your computer's LAN IP (e.g. http://192.168.1.23:4000)
/// — see the README for exactly which one to pass.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000',
);

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String baseUrl;
  String? token;
  final http.Client _client = http.Client();

  ApiClient({this.baseUrl = kApiBaseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Request failed';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) message = body['error'].toString();
    } catch (_) {}
    throw ApiException(res.statusCode, message);
  }

  Future<dynamic> get(String path) async {
    final res = await _client.get(_uri(path), headers: _headers);
    return _decode(res);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await _client.post(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    return _decode(res);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await _client.patch(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _client.delete(_uri(path), headers: _headers);
    return _decode(res);
  }

  /// Opens a Server-Sent Events stream and yields parsed `{event, data}`
  /// frames. Used for the live workflow execution feed
  /// (`/workflows/executions/:id/stream`). Closing the returned
  /// StreamSubscription (`.cancel()`) closes the underlying connection.
  Stream<Map<String, dynamic>> sse(String path) {
    final controller = StreamController<Map<String, dynamic>>();
    http.Client? sseClient;

    () async {
      sseClient = http.Client();
      final request = http.Request('GET', _uri(path));
      request.headers.addAll(_headers);
      try {
        final response = await sseClient!.send(request);
        if (response.statusCode != 200) {
          controller.addError(ApiException(response.statusCode, 'SSE connection failed'));
          await controller.close();
          return;
        }
        String eventName = 'message';
        final buffer = StringBuffer();
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          buffer.write(chunk);
          var text = buffer.toString();
          while (text.contains('\n')) {
            final idx = text.indexOf('\n');
            final line = text.substring(0, idx).trimRight();
            text = text.substring(idx + 1);
            if (line.startsWith('event:')) {
              eventName = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              final dataStr = line.substring(5).trim();
              if (dataStr.isNotEmpty) {
                try {
                  final data = jsonDecode(dataStr);
                  controller.add({'event': eventName, 'data': data});
                } catch (_) {}
              }
            } else if (line.isEmpty) {
              eventName = 'message';
            }
          }
          buffer
            ..clear()
            ..write(text);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }();

    controller.onCancel = () => sseClient?.close();
    return controller.stream;
  }
}
