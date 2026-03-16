import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

class OpenApiScanner {
  const OpenApiScanner();

  Future<void> scanAndGenerate({String? projectRoot}) async {
    final root = projectRoot ?? Directory.current.path;
    final libDir = p.join(root, 'lib');
    final routesDir = p.join(root, 'routes');

    final includedPaths = <String>[];
    if (Directory(libDir).existsSync()) includedPaths.add(libDir);
    if (Directory(routesDir).existsSync()) includedPaths.add(routesDir);

    if (includedPaths.isEmpty) {
      print('No lib/ or routes/ directory found!');
      return;
    }

    final collection = AnalysisContextCollection(includedPaths: [root]);

    final List<Map<String, dynamic>> routesInfo = [];

    for (final context in collection.contexts) {
      final analyzedFiles = context.contextRoot.analyzedFiles().toList();

      for (final filePath in analyzedFiles) {
        if (!filePath.endsWith('.dart')) continue;
        if (!_isInScanRoots(filePath, includedPaths)) continue;

        final session = context.currentSession;
        final unitResult = await session.getResolvedUnit(filePath);
        if (unitResult is ResolvedUnitResult) {
          _scanResolvedUnit(unitResult.unit, routesInfo);
        }
      }
    }

    await _generateOpenApiJson(routesInfo, root);
  }

  void _scanResolvedUnit(
    CompilationUnit unit,
    List<Map<String, dynamic>> routesInfo,
  ) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration) {
        _checkMetadataForRoute(declaration.metadata, routesInfo);
        continue;
      }

      if (declaration is TopLevelVariableDeclaration) {
        _checkMetadataForRoute(declaration.metadata, routesInfo);
        continue;
      }

      if (declaration is ClassDeclaration) {
        final body = declaration.body;
        if (body is BlockClassBody) {
          for (final member in body.members) {
            if (member is MethodDeclaration) {
              _checkMetadataForRoute(member.metadata, routesInfo);
            }
          }
        }
        continue;
      }

      if (declaration is MixinDeclaration) {
        for (final member in declaration.body.members) {
          if (member is MethodDeclaration) {
            _checkMetadataForRoute(member.metadata, routesInfo);
          }
        }
        continue;
      }

      if (declaration is ExtensionDeclaration) {
        for (final member in declaration.body.members) {
          if (member is MethodDeclaration) {
            _checkMetadataForRoute(member.metadata, routesInfo);
          }
        }
      }
    }
  }

  bool _isInScanRoots(String filePath, List<String> scanRoots) {
    for (final root in scanRoots) {
      if (p.equals(filePath, root) || p.isWithin(root, filePath)) {
        return true;
      }
    }
    return false;
  }

  void _checkMetadataForRoute(
    NodeList<Annotation> annotations,
    List<Map<String, dynamic>> routesInfo,
  ) {
    for (final annotation in annotations) {
      if (!_isRouteAnnotation(annotation)) continue;

      final value = annotation.elementAnnotation?.computeConstantValue();
      if (value == null) continue;

      final path = value.getField('path')?.toStringValue() ?? '';
      final description = value.getField('description')?.toStringValue() ?? '';
      final summary = value.getField('summary')?.toStringValue();
      final operationId = value.getField('operationId')?.toStringValue();
      final tags = _readStringList(value.getField('tags'));
      final requestBody = _buildRequestBody(value.getField('requestBody'));
      final responses = _buildResponses(value.getField('responses'));
      final deprecated = value.getField('deprecated')?.toBoolValue() ?? false;
      final methodField = value.getField('method');

      String methodStr = 'get';
      if (methodField != null) {
        final extractMethodName = methodField.variable?.name;
        if (extractMethodName != null) {
          methodStr = extractMethodName;
        } else {
          final index = methodField.getField('index')?.toIntValue();
          if (index != null && index >= 0) {
            // fallback mapping since we can't easily resolve the enum name without relying on HttpMethod
            const methods = [
              'delete',
              'get',
              'head',
              'options',
              'patch',
              'post',
              'put',
            ];
            if (index < methods.length) {
              methodStr = methods[index];
            }
          }
        }
      }

      routesInfo.add({
        'path': path,
        'description': description,
        'method': methodStr.toLowerCase(),
        'summary': summary,
        'operationId': operationId,
        'tags': tags,
        'requestBody': requestBody,
        'responses': responses,
        'deprecated': deprecated,
      });
    }
  }

  bool _isRouteAnnotation(Annotation annotation) {
    final element = annotation.element;
    if (element is ConstructorElement) {
      final enclosingClass = element.enclosingElement;
      if (enclosingClass.name != 'Route') return false;
      final libraryFragment = enclosingClass.library.firstFragment;
      final uri = libraryFragment.source.uri.toString();
      return uri.isEmpty || uri.contains('dart_frog_swagger');
    }

    return annotation.name.name == 'Route';
  }

  Future<void> _generateOpenApiJson(
    List<Map<String, dynamic>> routesInfo,
    String projectRoot,
  ) async {
    final paths = <String, dynamic>{};
    for (final route in routesInfo) {
      final path = route['path'] as String;
      final method = route['method'] as String;
      final description = route['description'] as String;
      final summary = route['summary'] as String?;
      final operationId = route['operationId'] as String?;
      final tags = route['tags'] as List<String>? ?? const [];
      final requestBody = route['requestBody'] as Map<String, dynamic>?;
      final responses = route['responses'] as Map<String, dynamic>?;
      final deprecated = route['deprecated'] as bool? ?? false;

      paths.putIfAbsent(path, () => <String, dynamic>{});
      final operation = <String, dynamic>{"description": description};
      if (summary != null && summary.isNotEmpty) {
        operation['summary'] = summary;
      }
      if (operationId != null && operationId.isNotEmpty) {
        operation['operationId'] = operationId;
      }
      if (tags.isNotEmpty) {
        operation['tags'] = tags;
      }
      if (deprecated) {
        operation['deprecated'] = true;
      }
      if (requestBody != null && requestBody.isNotEmpty) {
        operation['requestBody'] = requestBody;
      }

      if (responses != null && responses.isNotEmpty) {
        operation['responses'] = responses;
      } else {
        operation['responses'] = {
          "200": {"description": "Success"},
        };
      }

      paths[path][method] = operation;
    }

    const title = 'Dart Frog API';
    const version = '1.0.0';

    final info = <String, dynamic>{'title': title, 'version': version};

    final openapi = <String, dynamic>{
      "openapi": "3.0.0",
      "info": info,
      "paths": paths,
    };

    final buildDir = Directory(p.join(projectRoot, 'build'));
    if (!buildDir.existsSync()) {
      buildDir.createSync();
    }

    final jsonFile = File(p.join(buildDir.path, 'openapi.json'));
    final jsonStr = const JsonEncoder.withIndent("  ").convert(openapi);
    await jsonFile.writeAsString(jsonStr);
  }
}

List<String> _readStringList(DartObject? obj) {
  if (obj == null) return const [];
  final list = obj.toListValue();
  if (list == null) return const [];
  return [
    for (final entry in list)
      if (entry.toStringValue() != null) entry.toStringValue()!,
  ];
}

Map<String, dynamic>? _buildRequestBody(DartObject? obj) {
  if (obj == null) return null;
  final description = obj.getField('description')?.toStringValue();
  final required = obj.getField('required')?.toBoolValue();
  final contentType =
      obj.getField('contentType')?.toStringValue() ?? 'application/json';
  final schema = _dartObjectToJson(obj.getField('schema'));
  final example = _dartObjectToJson(obj.getField('example'));

  final result = <String, dynamic>{};
  if (description != null && description.isNotEmpty) {
    result['description'] = description;
  }
  if (required != null) {
    result['required'] = required;
  }

  if (schema != null || example != null) {
    final media = <String, dynamic>{};
    if (schema != null) {
      media['schema'] = schema;
    }
    if (example != null) {
      media['example'] = example;
    }
    result['content'] = {contentType: media};
  }

  return result.isEmpty ? null : result;
}

Map<String, dynamic>? _buildResponses(DartObject? obj) {
  if (obj == null) return null;
  final list = obj.toListValue();
  if (list == null || list.isEmpty) return null;

  final responses = <String, dynamic>{};
  for (final entry in list) {
    final statusCode = _readStatusCode(entry.getField('statusCode'));
    final description = entry.getField('description')?.toStringValue();
    final contentType =
        entry.getField('contentType')?.toStringValue() ?? 'application/json';
    final schema = _dartObjectToJson(entry.getField('schema'));
    final example = _dartObjectToJson(entry.getField('example'));

    if (statusCode == null || description == null || description.isEmpty) {
      continue;
    }

    final response = <String, dynamic>{'description': description};
    if (schema != null || example != null) {
      final media = <String, dynamic>{};
      if (schema != null) {
        media['schema'] = schema;
      }
      if (example != null) {
        media['example'] = example;
      }
      response['content'] = {contentType: media};
    }

    responses[statusCode] = response;
  }

  return responses.isEmpty ? null : responses;
}

String? _readStatusCode(DartObject? obj) {
  if (obj == null) return null;
  final intVal = obj.toIntValue();
  if (intVal != null) return intVal.toString();
  final strVal = obj.toStringValue();
  if (strVal != null && strVal.isNotEmpty) return strVal;
  return null;
}

dynamic _dartObjectToJson(DartObject? obj) {
  if (obj == null || obj.isNull) return null;
  final boolVal = obj.toBoolValue();
  if (boolVal != null) return boolVal;
  final intVal = obj.toIntValue();
  if (intVal != null) return intVal;
  final doubleVal = obj.toDoubleValue();
  if (doubleVal != null) return doubleVal;
  final stringVal = obj.toStringValue();
  if (stringVal != null) return stringVal;

  final listVal = obj.toListValue();
  if (listVal != null) {
    return [for (final entry in listVal) _dartObjectToJson(entry)];
  }

  final mapVal = obj.toMapValue();
  if (mapVal != null) {
    final map = <String, dynamic>{};
    mapVal.forEach((key, value) {
      final keyStr = _dartObjectToJson(key)?.toString() ?? '';
      map[keyStr] = _dartObjectToJson(value);
    });
    return map;
  }

  return obj.toString();
}
