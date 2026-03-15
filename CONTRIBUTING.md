# Contributing to dart_frog_swagger

First off, thank you for considering contributing to `dart_frog_swagger`! It's people like you that make dart_frog_swagger such a great tool.

## Where do I go from here?

If you've noticed a bug or have a feature request, please make sure to check the [issue tracker](https://github.com/vedantsingh1/dart_frog_swagger/issues) to see if someone else has already created an issue for it. If not, go ahead and [create one](https://github.com/vedantsingh1/dart_frog_swagger/issues/new)!

## Setting up your environment

Since this is a solo-maintained repository and external contributors do not have direct write access to the repository, you must use the standard GitHub **Fork & Pull Request** workflow to propose changes.

1.  **Fork the repo:** Click the "Fork" button at the top right of the GitHub page to create a copy of the repository in your own account.
2.  **Clone your fork:** Clone the forked repository to your local machine (`git clone https://github.com/<your-username>/dart_frog_swagger.git`).
3.  **Get dependencies:** Run `dart pub get` in the root of the project to fetch all dependencies.
4.  **Run tests:** Ensure everything is working properly by running `dart test`.
5.  **Run the analyzer:** Make sure the code passes the Dart analyzer with `dart analyze`.

## Developing

*   `lib/src/annotations/`: Contains the annotations (like `@Route`) used to decorate handlers.
*   `lib/src/generators/`: Contains the builder/source_gen logic that parses annotations and generates `build/openapi.json`.
*   `lib/src/middleware/`: Contains the Dart Frog middleware used to serve the Swagger UI and the OpenAPI JSON.
*   `example/`: Contains a sample Dart Frog server demonstrating how to use the package.

When modifying the code, please adhere to standard Dart formatting and style guidelines. You can format your code by running:

```bash
dart format .
```

## Making a Pull Request

1.  Create a new branch from `main` for your feature or bug fix: `git checkout -b my-new-feature`
2.  Make your changes and write tests if appropriate.
3.  Ensure that all tests and the analyzer pass:
    *   `dart test`
    *   `dart analyze`
4.  Commit your changes with a descriptive commit message.
5.  Push your branch to your fork: `git push origin my-new-feature`
6.  Open a Pull Request against the `main` branch of the original repository.

## Adding Tests

Before your pull request can be merged, please ensure that it is covered by tests.
If you're fixing a bug, please add a new test case that reproduces the bug, and then verify that the test passes after your fix.
If you're adding a feature, please add tests that cover the new functionality.

## Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms.
