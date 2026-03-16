import 'dart:convert';
import 'dart:io';

import 'package:dart_frog_swagger/src/cli/openapi_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('OpenApiScanner', () {
    const testFilePath = 'lib/__openapi_scanner_test.dart';
    const outputPath = 'build/openapi.json';

    String? originalSpec;

    setUp(() async {
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        originalSpec = await outputFile.readAsString();
      } else {
        originalSpec = null;
      }

      final testFile = File(testFilePath);
      await testFile.writeAsString(_testAnnotatedSource());
    });

    tearDown(() async {
      final testFile = File(testFilePath);
      if (await testFile.exists()) {
        await testFile.delete();
      }

      final outputFile = File(outputPath);
      if (originalSpec != null) {
        await outputFile.writeAsString(originalSpec!);
      } else if (await outputFile.exists()) {
        await outputFile.delete();
      }
    });

    test('generates full operation metadata', () async {
      await const OpenApiScanner().scanAndGenerate(
        projectRoot: Directory.current.path,
      );

      final outputFile = File(outputPath);
      expect(await outputFile.exists(), isTrue);

      final json =
          jsonDecode(await outputFile.readAsString()) as Map<String, dynamic>;
      final paths = json['paths'] as Map<String, dynamic>;

      final post = (paths['/widgets'] as Map<String, dynamic>)['post'] as Map;
      expect(post['summary'], equals('Create widget'));
      expect(post['description'], equals('Creates a widget.'));
      expect(post['operationId'], equals('createWidget'));
      expect(post['tags'], equals(['Widgets']));
      expect(post['deprecated'], isTrue);

      final requestBody = post['requestBody'] as Map<String, dynamic>;
      expect(requestBody['description'], equals('Widget payload'));
      expect(requestBody['required'], isTrue);
      final content = requestBody['content'] as Map<String, dynamic>;
      final media = content['application/json'] as Map<String, dynamic>;
      expect(media['schema'], isA<Map<String, dynamic>>());
      expect(media['example'], equals({'name': 'Gizmo'}));

      final responses = post['responses'] as Map<String, dynamic>;
      expect(responses.containsKey('201'), isTrue);
      expect(responses.containsKey('400'), isTrue);

      final created = responses['201'] as Map<String, dynamic>;
      expect(created['description'], equals('Created'));
      final createdContent = created['content'] as Map<String, dynamic>;
      final createdMedia =
          createdContent['application/json'] as Map<String, dynamic>;
      expect(createdMedia['schema'], isA<Map<String, dynamic>>());
      expect(createdMedia['example'], equals({'id': 1, 'name': 'Gizmo'}));

      final badRequest = responses['400'] as Map<String, dynamic>;
      expect(badRequest['description'], equals('Bad request'));
      expect(badRequest.containsKey('content'), isFalse);
    });

    test('omits optional sections when not provided', () async {
      await const OpenApiScanner().scanAndGenerate(
        projectRoot: Directory.current.path,
      );

      final json =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      final paths = json['paths'] as Map<String, dynamic>;

      final get = (paths['/widgets'] as Map<String, dynamic>)['get'] as Map;
      expect(get.containsKey('summary'), isFalse);
      expect(get.containsKey('operationId'), isFalse);
      expect(get.containsKey('tags'), isFalse);
      expect(get.containsKey('deprecated'), isFalse);
      expect(get.containsKey('requestBody'), isFalse);

      final responses = get['responses'] as Map<String, dynamic>;
      expect(
        responses,
        equals({
          '200': {'description': 'Success'},
        }),
      );
    });

    test('supports custom content types and minimal bodies', () async {
      await const OpenApiScanner().scanAndGenerate(
        projectRoot: Directory.current.path,
      );

      final json =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      final paths = json['paths'] as Map<String, dynamic>;

      final put =
          (paths['/widgets/{id}'] as Map<String, dynamic>)['put'] as Map;

      final requestBody = put['requestBody'] as Map<String, dynamic>;
      expect(requestBody['description'], equals('Update payload'));
      expect(requestBody['required'], isFalse);
      final requestContent = requestBody['content'] as Map<String, dynamic>;
      expect(requestContent.containsKey('application/xml'), isTrue);
      final requestMedia =
          requestContent['application/xml'] as Map<String, dynamic>;
      expect(requestMedia.containsKey('schema'), isFalse);
      expect(requestMedia['example'], equals('<widget id="1"/>'));

      final responses = put['responses'] as Map<String, dynamic>;
      final ok = responses['200'] as Map<String, dynamic>;
      expect(ok['description'], equals('Updated'));
      final okContent = ok['content'] as Map<String, dynamic>;
      expect(okContent.containsKey('text/plain'), isTrue);
      final okMedia = okContent['text/plain'] as Map<String, dynamic>;
      expect(okMedia.containsKey('schema'), isFalse);
      expect(okMedia['example'], equals('ok'));
    });
  });
}

String _testAnnotatedSource() {
  return '''
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_swagger/dart_frog_swagger.dart';

@Route(
  method: HttpMethod.post,
  path: '/widgets',
  summary: 'Create widget',
  description: 'Creates a widget.',
  operationId: 'createWidget',
  tags: const ['Widgets'],
  deprecated: true,
  requestBody: const ApiRequestBody(
    description: 'Widget payload',
    required: true,
    schema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
      },
      'required': ['name'],
    },
    example: {'name': 'Gizmo'},
  ),
  responses: const [
    ApiResponse(
      statusCode: 201,
      description: 'Created',
      schema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
          'name': {'type': 'string'},
        },
        'required': ['id', 'name'],
      },
      example: {'id': 1, 'name': 'Gizmo'},
    ),
    ApiResponse(
      statusCode: 400,
      description: 'Bad request',
    ),
  ],
)
Future<Response> createWidget(RequestContext context) async {
  return Response.json(body: {'id': 1, 'name': 'Gizmo'}, statusCode: 201);
}

@Route(
  method: HttpMethod.get,
  path: '/widgets',
  description: 'Lists widgets.',
)
Future<Response> listWidgets(RequestContext context) async {
  return Response.json(body: []);
}

@Route(
  method: HttpMethod.put,
  path: '/widgets/{id}',
  description: 'Updates a widget.',
  requestBody: const ApiRequestBody(
    description: 'Update payload',
    contentType: 'application/xml',
    example: '<widget id="1"/>',
  ),
  responses: const [
    ApiResponse(
      statusCode: 200,
      description: 'Updated',
      contentType: 'text/plain',
      example: 'ok',
    ),
  ],
)
Future<Response> updateWidget(RequestContext context) async {
  return Response(body: 'ok');
}
''';
}
