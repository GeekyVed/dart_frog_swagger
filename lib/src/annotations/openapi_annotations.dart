import 'package:meta/meta_meta.dart';
import 'package:dart_frog/dart_frog.dart';

@Target({TargetKind.function, TargetKind.method})
class Route {
  final HttpMethod method;
  final String path;
  final String description;

  const Route({
    required this.method,
    required this.path,
    required this.description,
  });
}
