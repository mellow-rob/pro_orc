import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class QuickActionsService {
  /// Opens project directory in Terminal.app (macOS system terminal).
  /// Uses `open -a Terminal <path>` — user approved as system standard ("Terminal.app ist OK").
  Future<void> openInTerminal(String projectPath) async {
    await Process.run('open', ['-a', 'Terminal', projectPath], runInShell: true);
  }

  /// Reveals project directory in Finder.
  Future<void> openInFinder(String projectPath) async {
    await Process.run('open', [projectPath], runInShell: true);
  }

  /// Opens Terminal.app, cd's into the project directory, and runs
  /// `claude /rem-sleep` to trigger memory consolidation.
  ///
  /// Uses osascript to open Terminal with a specific command, ensuring
  /// the claude CLI runs in the correct project context.
  Future<void> openRemSleep(String projectPath) async {
    final escapedPath = projectPath.replaceAll("'", "'\\''");
    await Process.run('osascript', [
      '-e',
      'tell application "Terminal" to do script "cd \'$escapedPath\' && claude /rem-sleep"',
    ], runInShell: true);
    // Bring Terminal to front
    await Process.run('open', ['-a', 'Terminal'], runInShell: true);
  }

  /// Opens a URL (GitHub or Notion) in the system default browser.
  /// Silently fails if URL cannot be launched (consistent with service error pattern).
  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri);
  }
}
