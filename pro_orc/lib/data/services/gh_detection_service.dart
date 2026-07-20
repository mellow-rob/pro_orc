import 'dart:developer' as developer;
import 'dart:io';

/// Detects whether the GitHub CLI is installed and the user is logged in.
///
/// Uses `which gh` to check for the binary and `gh auth status` to confirm
/// an active login. Both commands use `runInShell: true` (macOS GUI apps
/// don't inherit Homebrew PATH).
///
/// The [whichCommand] and [ghCommand] parameters enable testing with
/// nonexistent/fake binaries to verify error handling without depending on
/// the real CLI's installation or auth state.
class GhDetectionService {
  final String _whichCommand;
  final String _ghCommand;

  const GhDetectionService({
    String whichCommand = 'which',
    String ghCommand = 'gh',
  }) : _whichCommand = whichCommand,
       _ghCommand = ghCommand;

  /// Check if the GitHub CLI is installed AND the user is logged in.
  ///
  /// Returns `true` only when both `which gh` and `gh auth status` exit 0.
  /// Returns `false` (never throws) if the binary is missing, the user is
  /// not logged in, or any error occurs.
  Future<bool> isAvailable() async {
    try {
      final whichResult = await Process.run(_whichCommand, [
        _ghCommand,
      ], runInShell: true);
      if (whichResult.exitCode != 0) return false;

      final authResult = await Process.run(_ghCommand, [
        'auth',
        'status',
      ], runInShell: true);
      return authResult.exitCode == 0;
    } catch (e) {
      developer.log(
        'Failed to check gh CLI availability: $e',
        name: 'gh_detection_service',
      );
      return false;
    }
  }
}
