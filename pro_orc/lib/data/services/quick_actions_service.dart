import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class QuickActionsService {
  /// Opens Terminal.app and cd's into the project directory.
  /// Uses osascript for reliable directory navigation.
  Future<void> openInTerminal(String projectPath) async {
    final script = _terminalScript('cd "$projectPath"');
    await Process.run('osascript', ['-e', script], runInShell: true);
    await Process.run('open', ['-a', 'Terminal'], runInShell: true);
  }

  /// Reveals project directory in Finder.
  Future<void> openInFinder(String projectPath) async {
    await Process.run('open', [projectPath], runInShell: true);
  }

  /// Opens Terminal.app, cd's into the project directory, and runs
  /// Claude Code with the given prompt string.
  Future<void> openClaudeWithPrompt(String projectPath, String prompt) async {
    // Escape single quotes in prompt for shell safety
    final escapedPrompt = prompt.replaceAll("'", "'\\''");
    final script = _terminalScript("cd \"$projectPath\" && claude '$escapedPrompt'");
    await Process.run('osascript', ['-e', script], runInShell: true);
    await Process.run('open', ['-a', 'Terminal'], runInShell: true);
  }

  /// Opens Terminal.app, cd's into the project directory, and runs
  /// `claude /rem-sleep` to trigger memory consolidation.
  Future<void> openRemSleep(String projectPath) async {
    final script = _terminalScript('cd "$projectPath" && claude /rem-sleep');
    await Process.run('osascript', ['-e', script], runInShell: true);
    await Process.run('open', ['-a', 'Terminal'], runInShell: true);
  }

  /// Opens a URL (GitHub or Notion) in the system default browser.
  /// Silently fails if URL cannot be launched (consistent with service error pattern).
  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri);
  }

  /// Builds AppleScript to run a command in a new Terminal window.
  String _terminalScript(String command) {
    // Escape backslashes and double quotes for AppleScript string
    final escaped = command.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return 'tell application "Terminal" to do script "$escaped"';
  }
}
