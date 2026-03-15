import 'dart:convert';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:swagger_frog/swagger_frog.dart';

class OpenApiGenerator extends GeneratorForAnnotation<Route> {
  OpenApiGenerator([this.config = const {}]);

  final Map<String, dynamic> config;
  static final List<Map<String, String>> _routes = [];

  @override
  generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final method = _readApiMethod(annotation);
    final path = annotation.read('path').stringValue;
    final summary = annotation.read('description').stringValue;

    _routes.add({
      "method": method.toLowerCase(),
      "path": path,
      "summary": summary,
    });

    return null;
  }

  Future<void> finalize(BuildStep buildStep) async {
    final paths = <String, dynamic>{};

    for (final route in _routes) {
      final path = route["path"]!;
      final method = route["method"]!;
      final description = route["description"]!;

      paths.putIfAbsent(path, () => <String, dynamic>{});
      paths[path][method] = {
        "description": description,
        "responses": {
          "200": {"description": "Success"},
        },
      };
    }

    final title = _readString(config, 'title', 'Dart Frog API');
    final version = _readString(config, 'version', '1.0.0');
    final description = _readNullableString(config, 'description');
    final servers = _readServers(config);

    final info = <String, dynamic>{'title': title, 'version': version};
    if (description != null) info['description'] = description;

    final openapi = <String, dynamic>{
      "openapi": "3.0.0",
      "info": info,
      "paths": paths,
    };
    if (servers != null) openapi['servers'] = servers;

    final jsonStr = const JsonEncoder.withIndent("  ").convert(openapi);

    final file = AssetId(buildStep.inputId.package, 'build/openapi.json');

    await buildStep.writeAsString(file, jsonStr);
    _routes.clear();
  }
}

String _readString(Map<String, dynamic> config, String key, String fallback) {
  final value = config[key];
  if (value is String && value.trim().isNotEmpty) return value;
  return fallback;
}

String? _readNullableString(Map<String, dynamic> config, String key) {
  final value = config[key];
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

List<Map<String, dynamic>>? _readServers(Map<String, dynamic> config) {
  final value = config['servers'];
  if (value is List) {
    final servers = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) {
        servers.add({'url': item});
      } else if (item is Map<String, dynamic> && item['url'] != null) {
        servers.add(Map<String, dynamic>.from(item as Map));
      }
    }
    if (servers.isNotEmpty) return servers;
  }
  return null;
}

String _readApiMethod(ConstantReader reader) {
  final revived = reader.read('method').revive();
  if (revived.accessor.isNotEmpty) return revived.accessor;

  final index = reader
      .read('method')
      .objectValue
      .getField('index')
      ?.toIntValue();
  if (index != null && index >= 0 && index < ApiMethod.values.length) {
    return ApiMethod.values[index].name;
  }

  return 'get';
}
