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
  String? projectRoot,
}) {
  final normalizedDocsRoute = _normalizeRoute(docsRoute);
  final normalizedJsonRoute = _normalizeRoute(jsonRoute);

  return (Handler innerHandler) {
    return (context) async {
      final requestPath = _normalizeRoute(context.request.uri.path);

      if (requestPath == normalizedDocsRoute) {
        final file = File(jsonAssetPath);
        if (!await file.exists()) {
          return Response(
            statusCode: HttpStatus.internalServerError,
            body: _missingSpecHtml(
              jsonAssetPath: jsonAssetPath,
              projectRoot: projectRoot,
            ),
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }

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
            body: {
              'error': 'OpenAPI spec not found.',
              'path': jsonAssetPath,
              'hint': _missingSpecHint(projectRoot),
            },
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

String _missingSpecHint(String? projectRoot) {
  final rootNote = projectRoot == null ? '' : ' (projectRoot: $projectRoot)';
  return 'Run `dart run dart_frog_swagger` from your project root$rootNote to generate build/openapi.json.';
}

String _missingSpecHtml({required String jsonAssetPath, String? projectRoot}) {
  final hint = _missingSpecHint(projectRoot);
  return '''<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Swagger UI - Missing Spec</title>
    <link
      rel="stylesheet"
      href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css"
    />
    <link
      rel="stylesheet"
      href="https://fonts.googleapis.com/css2?family=Open+Sans:wght@400;600&family=Titillium+Web:wght@600;700&display=swap"
    />
    <style>
      body { margin: 0; background: #f6f7f9; color: #1f2937; }
      .topbar { background: #1b1b1b; color: #fff; padding: 12px 0; box-shadow: 0 2px 6px rgba(0,0,0,0.2); }
      .topbar .wrap { max-width: 1100px; margin: 0 auto; padding: 0 20px; display: flex; align-items: center; gap: 12px; }
      .topbar .brand { font-family: 'Titillium Web', sans-serif; font-weight: 700; font-size: 18px; letter-spacing: 0.3px; }
      .content { max-width: 1100px; margin: 32px auto; padding: 0 20px; font-family: 'Open Sans', sans-serif; }
      .card { background: #fff; border: 1px solid #e5e7eb; border-radius: 10px; padding: 24px; box-shadow: 0 8px 20px rgba(0,0,0,0.08); }
      .title { font-family: 'Titillium Web', sans-serif; font-size: 28px; margin: 0 0 8px; }
      .badge { display: inline-block; background: #fef2f2; color: #b91c1c; border: 1px solid #fecaca; border-radius: 999px; padding: 2px 10px; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.6px; margin-bottom: 12px; }
      .hint { background: #f9fafb; border: 1px dashed #d1d5db; border-radius: 8px; padding: 12px 14px; margin: 16px 0; }
      code { background: #f3f4f6; padding: 0.1rem 0.3rem; border-radius: 4px; }
      .list { margin: 12px 0 0; padding-left: 18px; }
    </style>
  </head>
  <body>
    <div class="topbar">
      <div class="wrap">
        <div class="brand">Swagger UI</div>
      </div>
    </div>
    <div class="content">
      <div class="card">
        <div class="badge">Error</div>
        <h1 class="title">Failed to load API definition</h1>
        <p>Expected file: <code>$jsonAssetPath</code></p>
        <div class="hint">
          <strong>Fix:</strong> $hint
        </div>
        <div>
          <strong>Quick checks:</strong>
          <ul class="list">
            <li>Run the CLI from your project root to regenerate the file.</li>
            <li>Verify the server has read access to the build directory.</li>
            <li>Restart the server after regenerating the spec.</li>
          </ul>
        </div>
      </div>
    </div>
  </body>
</html>
''';
}
