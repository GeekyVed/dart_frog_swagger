import 'package:meta/meta_meta.dart';
import 'package:dart_frog/dart_frog.dart';

@Target({TargetKind.function, TargetKind.method})
/// Annotation used to describe a Dart Frog route for OpenAPI generation.
class Route {
  /// HTTP method for the annotated handler.
  final HttpMethod method;

  /// Path template for the route (for example, `/users/:id`).
  final String path;

  /// Short human-readable description of what the route does.
  final String description;

  /// Optional summary shown above the description in Swagger UI.
  final String? summary;

  /// Optional operation id used by tooling/clients.
  final String? operationId;

  /// Optional tags used to group endpoints in Swagger UI.
  final List<String> tags;

  /// Optional request body metadata for the operation.
  final ApiRequestBody? requestBody;

  /// Optional responses for the operation.
  final List<ApiResponse> responses;

  /// Marks the operation as deprecated.
  final bool deprecated;

  /// Creates a new route annotation.
  const Route({
    required this.method,
    required this.path,
    required this.description,
    this.summary,
    this.operationId,
    this.tags = const [],
    this.requestBody,
    this.responses = const [],
    this.deprecated = false,
  });
}

/// Represents an OpenAPI request body.
class ApiRequestBody {
  /// Description of the request body.
  final String? description;

  /// Whether the request body is required.
  final bool required;

  /// Content type for the request body.
  final String contentType;

  /// JSON schema object. Must be a const map.
  final Map<String, Object?>? schema;

  /// Example payload. Must be a const literal.
  final Object? example;

  const ApiRequestBody({
    this.description,
    this.required = false,
    this.contentType = 'application/json',
    this.schema,
    this.example,
  });
}

/// Represents an OpenAPI response.
class ApiResponse {
  /// HTTP status code for the response.
  final int statusCode;

  /// Description of the response.
  final String description;

  /// Content type for the response.
  final String contentType;

  /// JSON schema object. Must be a const map.
  final Map<String, Object?>? schema;

  /// Example payload. Must be a const literal.
  final Object? example;

  const ApiResponse({
    required this.statusCode,
    required this.description,
    this.contentType = 'application/json',
    this.schema,
    this.example,
  });
}
