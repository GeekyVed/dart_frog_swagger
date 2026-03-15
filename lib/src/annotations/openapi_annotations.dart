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

  /// Creates a new route annotation.
  const Route({
    required this.method,
    required this.path,
    required this.description,
  });
}
