import 'package:flutter/material.dart';

import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Missing-GitHub-permission pre-flight popup (Spec 008, FR-004/FR-004a/
/// FR-008/FR-012/FR-013).
///
/// Given a [GhScopeStatus] (everything except [GhScopeStatus.present] — the
/// caller never shows this popup for `present`), renders one of two bodies:
///
/// - [GhScopeStatus.missing] and [GhScopeStatus.checkFailed] render the same
///   "Berechtigung fehlt" body with the `gh auth refresh -s delete_repo`
///   action button (FR-007: a failed/timed-out check is treated identically
///   to a confirmed-missing scope, never as "present").
/// - [GhScopeStatus.cliUnavailable] renders a distinct body explaining `gh`
///   itself is not installed/logged in, and does NOT offer the refresh
///   action button (FR-012) — that command would send the user down the
///   wrong troubleshooting path.
///
/// This is the ONLY permission-popup type in the app (FR-013): it carries no
/// bundling/sequencing logic for a second resource type (e.g. Vercel), so
/// two permission popups can never be composed together.
///
/// Three ways to dismiss without running any command: the close (X) icon,
/// the "Abbrechen" button, and an outside/barrier click (the caller opens
/// this via `showDialog` with the default `barrierDismissible: true`). The
/// action button itself also closes the popup immediately once the terminal
/// opens (FR-011) — it does not stay open waiting for the user to return.
class GithubPermissionPopup extends StatelessWidget {
  const GithubPermissionPopup({
    super.key,
    required this.status,
    required this.onOpenTerminal,
  });

  /// The pre-flight result driving which body/action this popup shows.
  /// Must not be [GhScopeStatus.present] — callers only show this popup on
  /// a blocking result.
  final GhScopeStatus status;

  /// Invoked when the user taps the action button (only ever shown for
  /// [GhScopeStatus.missing] / [GhScopeStatus.checkFailed]). The caller
  /// supplies the terminal runner (e.g.
  /// `QuickActionsService().openTerminalWithGhScopeRefresh`) — this widget
  /// never constructs a command string itself, so the constant,
  /// hard-coded `gh auth refresh -s delete_repo` command lives in exactly
  /// one place (FR-004a).
  final VoidCallback onOpenTerminal;

  static const String _title = 'Berechtigung fehlt';
  static const String _actionLabel =
      'Terminal oeffnen & Berechtigung nachfordern';
  static const String _cliUnavailableBody =
      'GitHub CLI (gh) ist nicht installiert oder nicht angemeldet';

  bool get _showsRefreshAction => status != GhScopeStatus.cliUnavailable;

  String get _bodyText {
    switch (status) {
      case GhScopeStatus.cliUnavailable:
        return _cliUnavailableBody;
      case GhScopeStatus.missing:
      case GhScopeStatus.checkFailed:
        return 'Die aktuelle GitHub-CLI-Session hat nicht den '
            "'delete_repo'-Scope. Dieser Scope muss gewaehrt werden, bevor "
            'das Repository geloescht werden kann.';
      case GhScopeStatus.present:
        // Callers never show this popup for `present` — kept exhaustive so
        // a future GhScopeStatus value fails to compile here instead of
        // silently falling through.
        return '';
    }
  }

  void _dismiss(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _onActionPressed(BuildContext context) {
    onOpenTerminal();
    // FR-011: close immediately once the terminal opens — no lingering
    // "waiting for terminal" state while the user is outside the app.
    _dismiss(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GlassDialog(
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, colors),
          const SizedBox(height: 16),
          _buildBody(colors),
          const SizedBox(height: 24),
          _buildButtons(context, colors),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors) {
    return Row(
      children: [
        Icon(Icons.lock_outline, color: Colors.amber.shade600, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _title,
            style: TextStyle(
              color: colors.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: colors.textDim, size: 20),
          onPressed: () => _dismiss(context),
          splashRadius: 16,
          tooltip: 'Schliessen',
        ),
      ],
    );
  }

  Widget _buildBody(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.textDim.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bodyText,
            style: TextStyle(color: colors.textSec, fontSize: 13),
          ),
          if (!_showsRefreshAction) ...[
            const SizedBox(height: 8),
            Text(
              'Bitte "gh auth login" im Terminal ausfuehren, um dich mit '
              'der GitHub-CLI anzumelden.',
              style: TextStyle(color: colors.textDim, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, AppColors colors) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: () => _dismiss(context),
          style: TextButton.styleFrom(foregroundColor: colors.textSec),
          child: const Text('Abbrechen'),
        ),
        if (_showsRefreshAction)
          FilledButton(
            onPressed: () => _onActionPressed(context),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.black,
            ),
            child: const Text(_actionLabel),
          ),
      ],
    );
  }
}
