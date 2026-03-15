import 'package:meta/meta_meta.dart';
import 'package:dart_frog_swagger/src/core/api_type_enum.dart';

@Target({TargetKind.function, TargetKind.method})
class Route {
  final ApiMethod method;
  final String path;
  final String description;

  const Route({
    required this.method,
    required this.path,
    required this.description,
  });
}
