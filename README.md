# swagger_frog

Generates OpenAPI (Swagger) specifications from annotated Dart Frog handlers and provides a simple Dart Frog middleware to serve a customizable Swagger UI documentation page.

## Features
- `@Route` annotation to describe endpoints directly alongside your handlers.
- Build runner builder that automatically produces `build/openapi.json`.
- Dart Frog middleware (`swaggerMiddleware`) to serve `/docs` (Swagger UI HTML) and `/openapi.json` with customizable titles, routes, and JSON transformations.

## Install
Add to your `pubspec.yaml`:
```yaml
dependencies:
  swagger_frog: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.0
```

## Annotate Routes
Use the `@Route` annotation in your Dart Frog files:
```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:swagger_frog/swagger_frog.dart';

@Route(
  method: ApiMethod.get,
  path: '/hello',
  description: 'Returns a friendly greeting.',
)
Future<Response> onRequest(RequestContext context) async {
  return Response(body: 'Hello');
}
```

## Generate OpenAPI
No extra configuration is strictly required. Simply run the build runner:
```bash
dart run build_runner build
```

The builder will scan files in `lib/` and `routes/` for annotations and write the specification to `build/openapi.json`.

### Advanced Configuration (Optional)
If you want to configure global options such as `title`, `version`, `description`, `servers`, or precisely which file globs to scan, you can add a `build.yaml` file to your project's root:
```yaml
targets:
  $default:
    builders:
      swagger_frog:
        generate_for:
          - lib/**.dart
          - routes/**.dart

builders:
  openapi_builder:
    import: "package:swagger_frog/builder.dart"
    builder_factories: ["openApiBuilder"]
    build_extensions: {"$package$": ["build/openapi.json"]}
    auto_apply: root_package
    build_to: source
    defaults:
      options:
        title: "My Custom API"
        version: "2.0.0"
        description: "API for my awesome Dart Frog application"
        include:
          - "lib/**.dart"
          - "routes/**.dart"
        servers:
          - "http://localhost:8080"
          - {"url": "https://api.myapp.com", "description": "Production"}
```

## Serve Swagger UI in Dart Frog
Mount the middleware inside your Dart Frog `_middleware.dart` configuration file:
```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:swagger_frog/swagger_frog.dart';

Handler middleware(Handler handler) {
  return handler.use(
    swaggerMiddleware(
      docsRoute: '/docs', // where Swagger UI stands
      title: 'My Custom API Docs',
      jsonRoute: '/openapi.json', // endpoint serving JSON
      jsonAssetPath: 'build/openapi.json', // where builder places json
      transformJson: (json) {
        // Optional hook: dynamically apply modifications to the JSON
        json['info']['title'] = 'My Custom API Docs';
        return json;
      },
    )
  );
}
```

## Configuration Options

### Builder options (in `build.yaml`):
- `title`: OpenAPI `info.title`
- `version`: OpenAPI `info.version`
- `description`: OpenAPI `info.description`
- `servers`: list of URL string paths or `{url, description}` objects
- `include`: file globs to scan for `@Route` annotations

### Middleware options (`swaggerMiddleware`):
- `docsRoute`: Route endpoint for Swagger UI (default: `/docs`)
- `title`: HTML page `<title>` (default: `API Docs`)
- `jsonRoute`: Route endpoint to serve the OpenAPI JSON (default: `/openapi.json`)
- `jsonAssetPath`: Filename path to load the generated JSON from (default: `build/openapi.json`)
- `jsonOverride`: Provide a Map JSON directly, bypassing file reading
- `transformJson`: Hook to modify the JSON immediately before sending the response

