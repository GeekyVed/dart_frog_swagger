import 'package:dart_frog_swagger/src/cli/openapi_scanner.dart';

void main(List<String> arguments) async {
  final scanner = OpenApiScanner();
  await scanner.scanAndGenerate();
}
