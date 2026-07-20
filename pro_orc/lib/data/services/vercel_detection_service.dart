import 'dart:developer' as developer;
import 'dart:io';

/// Detects whether the Vercel CLI is installed and the user is logged in.
///
/// Uses `which vercel` to check for the binary and `vercel whoami` to
/// confirm an active login. Both commands use `runInShell: true` (macOS
/// GUI apps don't inherit Homebrew PATH).
///
/// The [whichCommand] and [vercelCommand] parameters enable testing with
/// nonexistent/fake binaries to verify error handling without depending on
/// the real CLI's installation or auth state.
class VercelDetectionService {
  final String _whichCommand;
  final String _vercelCommand;

  const VercelDetectionService({
    String whichCommand = 'which',
    String vercelCommand = 'vercel',
  }) : _whichCommand = whichCommand,
       _vercelCommand = vercelCommand;

  /// Check if the Vercel CLI is installed AND the user is logged in.
  ///
  /// Returns `true` only when both `which vercel` and `vercel whoami` exit
  /// 0. Returns `false` (never throws) if the binary is missing, the user
  /// is not logged in, or any error occurs.
  Future<bool> isAvailable() async {
    try {
      final whichResult = await Process.run(_whichCommand, [
        _vercelCommand,
      ], runInShell: true);
      if (whichResult.exitCode != 0) return false;

      final whoamiResult = await Process.run(_vercelCommand, [
        'whoami',
      ], runInShell: true);
      return whoamiResult.exitCode == 0;
    } catch (e) {
      developer.log(
        'Failed to check Vercel CLI availability: $e',
        name: 'vercel_detection_service',
      );
      return false;
    }
  }
}
