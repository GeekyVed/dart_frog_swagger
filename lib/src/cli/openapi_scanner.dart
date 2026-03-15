import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
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

    final List<Map<String, String>> routesInfo = [];

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
    List<Map<String, String>> routesInfo,
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
    List<Map<String, String>> routesInfo,
  ) {
    for (final annotation in annotations) {
      if (!_isRouteAnnotation(annotation)) continue;

      final value = annotation.elementAnnotation?.computeConstantValue();
      if (value == null) continue;

      final path = value.getField('path')?.toStringValue() ?? '';
      final description = value.getField('description')?.toStringValue() ?? '';
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
    List<Map<String, String>> routesInfo,
    String projectRoot,
  ) async {
    final paths = <String, dynamic>{};
    for (final route in routesInfo) {
      final path = route['path']!;
      final method = route['method']!;
      final description = route['description']!;

      paths.putIfAbsent(path, () => <String, dynamic>{});
      paths[path][method] = {
        "description": description,
        "responses": {
          "200": {"description": "Success"},
        },
      };
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
