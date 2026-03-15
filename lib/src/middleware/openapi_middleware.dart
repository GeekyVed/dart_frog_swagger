import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

Middleware swaggerMiddleware({
  String docsRoute = '/docs',
  String title = 'API Docs',
  String jsonRoute = '/openapi.json',
  String jsonAssetPath = 'build/openapi.json',
  Map<String, dynamic>? jsonOverride,
  Map<String, dynamic> Function(Map<String, dynamic> json)? transformJson,
}) {
  final normalizedDocsRoute = _normalizeRoute(docsRoute);
  final normalizedJsonRoute = _normalizeRoute(jsonRoute);

  return (Handler innerHandler) {
    return (context) async {
      final requestPath = _normalizeRoute(context.request.uri.path);

      if (requestPath == normalizedDocsRoute) {
        return Response(
          body: _swaggerUiHtml(title, normalizedJsonRoute),
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }

      if (requestPath == normalizedJsonRoute) {
        final json = await _loadOpenApiJson(
          jsonAssetPath: jsonAssetPath,
          jsonOverride: jsonOverride,
          transformJson: transformJson,
        );

        if (json == null) {
          return Response.json(
            statusCode: HttpStatus.internalServerError,
            body: {'error': 'OpenAPI spec not found.', 'path': jsonAssetPath},
          );
        }

        return Response.json(body: json);
      }

      return innerHandler(context);
    };
  };
}

Future<Map<String, dynamic>?> _loadOpenApiJson({
  required String jsonAssetPath,
  Map<String, dynamic>? jsonOverride,
  Map<String, dynamic> Function(Map<String, dynamic> json)? transformJson,
}) async {
  Map<String, dynamic>? json = jsonOverride;

  if (json == null) {
    final file = File(jsonAssetPath);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      json = decoded;
    } else if (decoded is Map) {
      json = decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  }

  if (json == null) return null;

  if (transformJson != null) {
    json = transformJson(json);
  }

  return json;
}

String _normalizeRoute(String route) {
  var normalized = route.trim();
  if (!normalized.startsWith('/')) normalized = '/$normalized';
  if (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String _swaggerUiHtml(String title, String jsonRoute) {
  return '''<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$title</title>
    <link
      rel="stylesheet"
      href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css"
    />
    <style>
      html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
      *, *:before, *:after { box-sizing: inherit; }
      body { margin: 0; background: #f3f4f6; }
    </style>
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
    <script>
      window.onload = function() {
        window.ui = SwaggerUIBundle({
          url: "$jsonRoute",
          dom_id: '#swagger-ui',
          deepLinking: true,
          presets: [
            SwaggerUIBundle.presets.apis,
            SwaggerUIStandalonePreset
          ],
          layout: "StandaloneLayout"
        });
      };
    </script>
  </body>
</html>
''';
}
