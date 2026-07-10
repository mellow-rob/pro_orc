import 'dart:developer' as developer;
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Valid slash-command skill names: an optional leading slash, then letters,
/// digits and `:_-`. Guards against typos and shell-metacharacter injection.
final RegExp _skillNamePattern = RegExp(r'^/?[A-Za-z0-9:_-]+$');

/// True if [skillName] is a syntactically valid skill/slash-command name.
bool isValidSkillName(String skillName) =>
    _skillNamePattern.hasMatch(skillName);

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

  /// Opens a URL (e.g. GitHub) in the system default browser.
  /// Silently fails if URL cannot be launched (consistent with service error pattern).
  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri);
  }

  /// Builds the AppleScript command to open Claude in the given directory.
  /// Exposed for testability.
  String buildClaudeScript(String projectPath) {
    return _terminalScript('cd "$projectPath" && claude');
  }

  /// Builds the shell command that launches Claude Code in [projectPath] with
  /// the given [skillName] pre-invoked as a slash command — `claude "/<skill>"`
  /// (AD-4). Pure and exposed for testing so the escaping of paths and skill
  /// names is verifiable without spawning a process.
  ///
  /// Both the path (double-quoted) and the skill argument (double-quoted) are
  /// escaped for the shell: backslashes and double quotes are backslash-escaped
  /// so a path or skill name containing them cannot break out of its quotes.
  /// The leading slash of the slash command is added here — pass the bare
  /// skill name (e.g. `a1-fix`), with or without a leading slash.
  String buildSkillLaunchCommand(String projectPath, String skillName) {
    final path = _shellEscapeDoubleQuoted(projectPath);
    final skill = skillName.startsWith('/') ? skillName : '/$skillName';
    final skillArg = _shellEscapeDoubleQuoted(skill);
    return 'cd "$path" && claude "$skillArg"';
  }

  /// Opens Terminal.app, cd's into [projectPath], and starts Claude Code with
  /// [skillName] invoked as a slash command. Rejects (and logs) a skill name
  /// that fails [isValidSkillName] — an early typo/injection guard.
  Future<void> openClaudeWithSkill(String projectPath, String skillName) async {
    if (!isValidSkillName(skillName)) {
      developer.log('Refusing to launch invalid skill name: "$skillName"',
          name: 'quick_actions');
      return;
    }
    final script = _terminalScript(buildSkillLaunchCommand(projectPath, skillName));
    await Process.run('osascript', ['-e', script], runInShell: true);
    await Process.run('open', ['-a', 'Terminal'], runInShell: true);
  }

  /// Escapes a value to sit safely inside a double-quoted shell string.
  String _shellEscapeDoubleQuoted(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  /// Opens Terminal.app, cd's into the project directory, and starts Claude Code.
  Future<void> openClaude(String projectPath) async {
    final script = buildClaudeScript(projectPath);
    await Process.run('osascript', ['-e', script], runInShell: true);
    await Process.run('open', ['-a', 'Terminal'], runInShell: true);
  }

  /// Builds AppleScript to run a command in a new Terminal window.
  String _terminalScript(String command) {
    // Escape backslashes and double quotes for AppleScript string
    final escaped = command.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return 'tell application "Terminal" to do script "$escaped"';
  }
}
