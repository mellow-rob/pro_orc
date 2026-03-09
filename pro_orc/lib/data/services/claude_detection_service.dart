import 'dart:io';

/// Detects whether the Claude Code CLI is installed on the system.
///
/// Uses `which claude` to check for the binary and `claude --version`
/// to retrieve the version string. Both commands use `runInShell: true`
/// (macOS GUI apps don't inherit Homebrew PATH).
///
/// The [whichCommand] and [claudeCommand] parameters enable testing
/// with nonexistent binaries to verify error handling.
class ClaudeDetectionService {
  final String _whichCommand;
  final String _claudeCommand;

  const ClaudeDetectionService({
    String whichCommand = 'which',
    String claudeCommand = 'claude',
  })  : _whichCommand = whichCommand,
        _claudeCommand = claudeCommand;

  /// Check if Claude Code CLI is installed via `which claude`.
  Future<bool> isClaudeInstalled() async {
    try {
      final result = await Process.run(
        _whichCommand,
        [_claudeCommand],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Get Claude CLI version string, or null if not installed.
  Future<String?> getClaudeVersion() async {
    try {
      final result = await Process.run(
        _claudeCommand,
        ['--version'],
        runInShell: true,
      );
      if (result.exitCode != 0) return null;
      final output = (result.stdout as String).trim();
      return output.isEmpty ? null : output;
    } catch (_) {
      return null;
    }
  }
}
