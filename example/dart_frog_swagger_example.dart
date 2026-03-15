/// Example showing how to use dart_frog_swagger to generate OpenAPI docs
/// for your Dart Frog application.
library;

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_swagger/dart_frog_swagger.dart';

/// 1. Define routes using the @Route annotation.
/// The `dart_frog_swagger` builder will scan for these annotations 
/// across your lib/ and routes/ directories.
@Route(
  method: ApiMethod.get, 
  path: '/users',
  description: 'Fetches a list of all users available in the system.',
)
Future<Response> onRequestUsers(RequestContext context) async {
  return Response.json(body: [
    {'id': 1, 'name': 'John Doe'},
    {'id': 2, 'name': 'Jane Smith'},
  ]);
}

@Route(
  method: ApiMethod.post, 
  path: '/users',
  description: 'Creates a new user.',
)
Future<Response> onCreateUser(RequestContext context) async {
  return Response.json(body: {'id': 3, 'name': 'New User'}, statusCode: 201);
}

/// 2. Serve the Swagger UI and OpenAPI JSON via a middleware.
/// Mount this in your main `_middleware.dart` file.
Handler middleware(Handler handler) {
  return handler.use(
    swaggerMiddleware(
      docsRoute: '/docs', // Where the Swagger UI will be hosted
      title: 'Example API Documentation', // HTML page title
      jsonRoute: '/openapi.json', // Where the raw JSON spec is hosted
      jsonAssetPath: 'build/openapi.json', // Where the builder output is saved
      transformJson: (json) {
        // Optional: modify the generated JSON dynamically before serving
        json['info']['version'] = '1.1.0';
        return json;
      },
    ),
  );
}
