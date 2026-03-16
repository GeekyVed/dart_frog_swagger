## 1.1.0

- Added request body and response metadata to `@Route` (schema, examples, content type).
- Added operation metadata (summary, tags, operationId, deprecated) for richer Swagger UI output.
- Improved OpenAPI generation logic and test coverage for new features.

## 1.0.1

- Added `@Route` annotation for describing endpoints.
- Added CLI that scans Dart Frog routes and generates `build/openapi.json`.
- Added Dart Frog middleware for Swagger UI and JSON serving.
