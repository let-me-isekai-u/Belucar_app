# belucar_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Concert API environment

The customer concert flow uses the production API by default. Override the
host for a development or staging build with a Dart define (do not include the
`/api/v1/concert` path):

```bash
flutter run --dart-define=CONCERT_API_BASE_URL=https://your-dev-host
```
