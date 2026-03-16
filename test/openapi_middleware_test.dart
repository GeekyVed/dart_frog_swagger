import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_swagger/dart_frog_swagger.dart';
import 'package:test/test.dart';

void main() {
  group('openApiDocsMiddleware', () {
    test('serves swagger ui html at docs route', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dart_frog_swagger_docs',
      );
      final jsonFile = File('${tempDir.path}/openapi.json');
      await jsonFile.writeAsString(
        jsonEncode({
          'openapi': '3.0.0',
          'info': {'title': 'Test', 'version': '1.0.0'},
        }),
      );

      final server = await _startServer(
        docsRoute: '/docs',
        title: 'My API Docs',
        jsonAssetPath: jsonFile.path,
      );

      try {
        final response = await _get(server.baseUri.resolve('/docs'));
        expect(response.statusCode, equals(200));
        expect(
          response.headers.value(HttpHeaders.contentTypeHeader),
          contains('text/html'),
        );
        expect(response.body, contains('<title>My API Docs</title>'));
        expect(response.body, contains('swagger-ui'));
      } finally {
        await server.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('serves openapi json with overrides and transforms', () async {
      final server = await _startServer(
        jsonRoute: '/openapi.json',
        jsonOverride: {
          'openapi': '3.0.0',
          'info': {'title': 'Original', 'version': '1.0.0'},
        },
        transformJson: (json) {
          json['info']['title'] = 'Transformed';
          return json;
        },
      );

      try {
        final response = await _get(server.baseUri.resolve('/openapi.json'));
        expect(response.statusCode, equals(200));

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        expect(decoded['openapi'], equals('3.0.0'));
        expect(decoded['info']['title'], equals('Transformed'));
      } finally {
        await server.close();
      }
    });

    test('reads openapi json from file when provided', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'dart_frog_swagger',
      );
      final jsonFile = File('${tempDir.path}/openapi.json');
      await jsonFile.writeAsString(
        jsonEncode({
          'openapi': '3.0.0',
          'info': {'title': 'From File', 'version': '1.0.0'},
        }),
      );

      final server = await _startServer(
        jsonRoute: '/spec.json',
        jsonAssetPath: jsonFile.path,
      );

      try {
        final response = await _get(server.baseUri.resolve('/spec.json'));
        expect(response.statusCode, equals(200));

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        expect(decoded['info']['title'], equals('From File'));
      } finally {
        await server.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('falls through to inner handler for other routes', () async {
      final server = await _startServer();

      try {
        final response = await _get(server.baseUri.resolve('/health'));
        expect(response.statusCode, equals(200));
        expect(response.body, equals('ok'));
      } finally {
        await server.close();
      }
    });
  });
}

Future<_TestServer> _startServer({
  String docsRoute = '/docs',
  String title = 'API Docs',
  String jsonRoute = '/openapi.json',
  String jsonAssetPath = 'build/openapi.json',
  Map<String, dynamic>? jsonOverride,
  Map<String, dynamic> Function(Map<String, dynamic> json)? transformJson,
}) async {
  final handler = swaggerMiddleware(
    docsRoute: docsRoute,
    title: title,
    jsonRoute: jsonRoute,
    jsonAssetPath: jsonAssetPath,
    jsonOverride: jsonOverride,
    transformJson: transformJson,
  )((context) async => Response(body: 'ok'));

  final server = await serve(handler, InternetAddress.loopbackIPv4, 0);
  final baseUri = Uri.parse('http://${server.address.host}:${server.port}');

  return _TestServer(server, baseUri);
}

Future<_HttpResult> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return _HttpResult(response.statusCode, response.headers, body);
  } finally {
    client.close(force: true);
  }
}

class _TestServer {
  _TestServer(this.server, this.baseUri);

  final HttpServer server;
  final Uri baseUri;

  Future<void> close() => server.close(force: true);
}

class _HttpResult {
  _HttpResult(this.statusCode, this.headers, this.body);

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}
