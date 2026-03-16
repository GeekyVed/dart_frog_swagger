# dart_frog_swagger

Generates OpenAPI (Swagger) specifications from annotated Dart Frog handlers and provides a simple Dart Frog middleware to serve a customizable Swagger UI documentation page.

## Features
- `@Route` annotation to describe endpoints directly alongside your handlers.
- Optional request/response metadata (body schema, examples, tags, summary) for richer Swagger UI output.
- Analyzer-powered CLI that scans your project (including `routes/`) and produces `build/openapi.json`.
- Dart Frog middleware (`swaggerMiddleware`) to serve `/docs` (Swagger UI HTML) and `/openapi.json` with customizable titles, routes, and JSON transformations.

## Install
Add to your `pubspec.yaml`:
```yaml
dependencies:
  dart_frog_swagger: ^1.0.0
```

## Annotate Routes
Use the `@Route` annotation in your Dart Frog files:
```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_swagger/dart_frog_swagger.dart';

@Route(
  method: HttpMethod.get,
  path: '/hello',
  summary: 'Say hello',
  description: 'Returns a friendly greeting.',
  tags: const ['Greeting'],
  responses: const [
    ApiResponse(
      statusCode: 200,
      description: 'Greeting payload',
      schema: const {
        'type': 'object',
        'properties': {
          'message': {'type': 'string', 'example': 'Hello'},
        },
        'required': ['message'],
      },
    ),
  ],
)
Future<Response> onRequest(RequestContext context) async {
  return Response(body: 'Hello');
}
```

## Generate OpenAPI
No extra configuration is strictly required. Run:
```bash
dart run dart_frog_swagger
```

The CLI scans files in `lib/` and `routes/` for annotations and writes the specification to `build/openapi.json`.
Run it from your project root so `lib/` and `routes/` are resolved correctly.

## Serve Swagger UI in Dart Frog
Mount the middleware inside your Dart Frog `_middleware.dart` configuration file:
```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_swagger/dart_frog_swagger.dart';

Handler middleware(Handler handler) {
  return handler.use(
    swaggerMiddleware(
      docsRoute: '/docs', // where Swagger UI stands
      title: 'My Custom API Docs',
      jsonRoute: '/openapi.json', // endpoint serving JSON
      jsonAssetPath: 'build/openapi.json', // where the CLI writes json
      projectRoot: '.', // optional: used in error hints if JSON is missing
      transformJson: (json) {
        // Optional hook: dynamically apply modifications to the JSON
        json['info']['title'] = 'My Custom API Docs';
        return json;
      },
    )
  );
}
```

## Troubleshooting
- **No output file**: Ensure you ran the CLI from the project root.
- **Nothing found**: Confirm `routes/` or `lib/` exists and contains `@Route` annotations.
- **Stale output**: Re-run `dart run dart_frog_swagger` after code changes.
- **Deployment with build/ ignored**: Run `dart run dart_frog_swagger` during build/deploy. If the JSON file is missing, `/docs` shows a clear error page with the CLI command.

## Configuration Options

### Middleware options (`swaggerMiddleware`):
  - `docsRoute`: Route endpoint for Swagger UI (default: `/docs`)
  - `title`: HTML page `<title>` (default: `API Docs`)
  - `jsonRoute`: Route endpoint to serve the OpenAPI JSON (default: `/openapi.json`)
  - `jsonAssetPath`: Filename path to load the generated JSON from (default: `build/openapi.json`)
  - `jsonOverride`: Provide a Map JSON directly, bypassing file reading
  - `transformJson`: Hook to modify the JSON immediately before sending the response
  - `projectRoot`: Optional path used in error hints when the JSON file is missing

## Contributing
Please see the [CONTRIBUTING.md](CONTRIBUTING.md) file for more details on how to get started!
