import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'src/generators/openapi_generator.dart';

Builder openApiBuilder(BuilderOptions options) => SimpleOpenApiBuilder(options);

class SimpleOpenApiBuilder implements Builder {
  SimpleOpenApiBuilder(this.options);

  final BuilderOptions options;

  @override
  final buildExtensions = const {
    r'$package$': ['build/openapi.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final generator = OpenApiGenerator(options.config);

    // Use glob from config, or default to lib and routes
    List<String> globs = ['lib/**.dart', 'routes/**.dart'];
    if (options.config['include'] is List) {
      globs = (options.config['include'] as List).cast<String>();
    }

    final Set<AssetId> visited = {};
    for (final pattern in globs) {
      final assets = buildStep.findAssets(Glob(pattern));
      await for (final asset in assets) {
        if (!visited.add(asset)) continue;
        if (!await buildStep.resolver.isLibrary(asset)) continue;
        final library = await buildStep.resolver.libraryFor(asset);
        final reader = LibraryReader(library);
        await generator.generate(reader, buildStep);
      }
    }

    await generator.finalize(buildStep);
  }
}
