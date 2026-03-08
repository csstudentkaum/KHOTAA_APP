/// Central app configuration.
/// 
/// The server URL is injected at build time via --dart-define:
///   flutter run --dart-define=SERVER_URL=https://khotaa-email-server.vercel.app
///
/// In VS Code, add to .vscode/launch.json under "args":
///   "--dart-define=SERVER_URL=https://khotaa-email-server.vercel.app"
class AppConfig {
  AppConfig._();

  /// Base URL of the Vercel server. Never hardcoded — always from --dart-define.
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'https://khotaa-email-server.vercel.app',
  );
}
