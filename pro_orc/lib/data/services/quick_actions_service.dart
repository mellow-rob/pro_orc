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

  /// Opens Terminal.app at the project directory for Claude rem-sleep interaction.
  ///
  /// Opens a Terminal window at [projectPath] where the user can run
  /// `claude` to interact with memory consolidation (rem-sleep workflow).
  Future<void> openRemSleep(String projectPath) async {
    await Process.run('open', ['-a', 'Terminal', projectPath], runInShell: true);
  }

  /// Opens a URL (GitHub or Notion) in the system default browser.
  /// Silently fails if URL cannot be launched (consistent with service error pattern).
  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri);
  }
}
