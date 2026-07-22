import 'package:flutter/material.dart';

import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/features/shell/glass_dialog.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Extracts the repo owner (first path segment) from a GitHub URL of the
/// form `https://github.com/<owner>/<repo>` (Spec 009, FR-001/FR-002).
///
/// Returns `null` when [githubUrl] does not parse into a [Uri] or has no
/// non-empty first path segment (e.g. `https://github.com/` or a
/// non-URL string) — callers must treat `null` as "cannot determine
/// owner" and fall back to owner-less copy, never render an empty/blank
/// bold token.
///
/// The URL passed in always originates from the app's own git-remote
/// config (`git_reader.dart::_remoteToGithubUrl`), never from raw user
/// input, so simple path-segment parsing is sufficient here — no regex
/// hardening needed.
String? extractGithubOwner(String githubUrl) {
  final uri = Uri.tryParse(githubUrl);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;

  final segments = uri.pathSegments;
  if (segments.isEmpty) return null;
  final owner = segments.first;
  return owner.isEmpty ? null : owner;
}

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
    this.onOpenTerminalLogin,
    this.repoOwner,
    this.activeAccount,
  });

  /// The pre-flight result driving which body/action this popup shows.
  /// Must not be [GhScopeStatus.present] — callers only show this popup on
  /// a blocking result.
  final GhScopeStatus status;

  /// The GitHub repo owner (e.g. `'acme-corp'`), already extracted by the
  /// caller via [extractGithubOwner] from the resource's `githubUrl`
  /// (Spec 009, FR-001). This widget does NOT parse URLs itself —
  /// separation of concerns keeps the extraction in exactly one place.
  ///
  /// `null` means the owner could not be determined (FR-002 fallback):
  /// the body renders the previous owner-less text unchanged, for both
  /// affected states.
  final String? repoOwner;

  /// The login of the currently active `gh` CLI account, already resolved
  /// by the caller via `GhDetectionService.getActiveAccountLogin()`
  /// (2026-07-22-gh-auth-refresh-wrong-account). `null` means "could not be
  /// determined" and is treated the SAME as "no mismatch" — [_accountMismatch]
  /// only becomes `true` when both [activeAccount] and [repoOwner] are
  /// known AND differ. This is a conservative default: an unknown active
  /// account must never trigger the mismatch copy/flow, since that flow
  /// would be wrong if there actually is no mismatch.
  final String? activeAccount;

  /// Invoked when the user taps the action button in the NO-mismatch case
  /// (only ever shown for [GhScopeStatus.missing] / [GhScopeStatus.checkFailed]).
  /// The caller supplies the terminal runner (e.g.
  /// `QuickActionsService().openTerminalWithGhScopeRefresh`) — this widget
  /// never constructs a command string itself, so the constant,
  /// hard-coded `gh auth refresh -s delete_repo` command lives in exactly
  /// one place (FR-004a).
  ///
  /// NOT invoked when [_accountMismatch] is `true` — see
  /// [onOpenTerminalLogin].
  final VoidCallback onOpenTerminal;

  /// Invoked when the user taps the action button in the account-MISMATCH
  /// case instead of [onOpenTerminal] — `gh auth refresh` structurally
  /// cannot target a different account (verified against `gh auth refresh
  /// --help`, no `--user` flag), so the mismatch case must run a different
  /// command (`gh auth login -s delete_repo`, see
  /// `QuickActionsService().openTerminalWithGhScopeLogin`) instead
  /// (2026-07-22-gh-auth-refresh-wrong-account). `null` is only safe when
  /// the caller never passes `activeAccount`/`repoOwner` combinations that
  /// can produce a mismatch; callers that do must supply this.
  final VoidCallback? onOpenTerminalLogin;

  static const String _title = 'Berechtigung fehlt';
  static const String _actionLabel =
      'Terminal oeffnen & Berechtigung nachfordern';
  static const String _cliUnavailableBody =
      'GitHub CLI (gh) ist nicht installiert oder nicht angemeldet';
  static const String _missingBody =
      'Die aktuelle GitHub-CLI-Session hat nicht den '
      "'delete_repo'-Scope. Dieser Scope muss gewaehrt werden, bevor "
      'das Repository geloescht werden kann.';

  bool get _showsRefreshAction => status != GhScopeStatus.cliUnavailable;

  /// `true` only when both [activeAccount] and [repoOwner] are known and
  /// they differ — the case where `gh auth refresh` would fail with
  /// "error refreshing credentials for X, received credentials for Y"
  /// (2026-07-22-gh-auth-refresh-wrong-account). An unknown [activeAccount]
  /// (lookup failed) is conservatively treated as "no mismatch": the
  /// original `gh auth refresh` copy/flow stays in place, which is exactly
  /// today's pre-existing behavior for anyone whose active account happens
  /// to match, and merely non-actionable (not actively misleading) for the
  /// rare case where it doesn't and the lookup also failed.
  bool get _accountMismatch {
    final active = activeAccount;
    final owner = repoOwner;
    if (active == null || owner == null) return false;
    return active != owner;
  }

  /// The owner-less fallback body text for the current [status] (FR-002)
  /// — unchanged from the pre-Spec-009 behaviour.
  String get _bodyTextFallback {
    switch (status) {
      case GhScopeStatus.cliUnavailable:
        return _cliUnavailableBody;
      case GhScopeStatus.missing:
      case GhScopeStatus.checkFailed:
        return _missingBody;
      case GhScopeStatus.present:
        // Callers never show this popup for `present` — kept exhaustive so
        // a future GhScopeStatus value fails to compile here instead of
        // silently falling through.
        return '';
    }
  }

  /// Builds the body's rich-text spans (Spec 009, FR-001/FR-002; extended
  /// 2026-07-22-gh-auth-refresh-wrong-account for the account-mismatch
  /// case).
  ///
  /// When [repoOwner] is present, weaves in an owner hint ahead of the
  /// existing status-specific explanation, with the owner name in its own
  /// bold [TextSpan] — the surrounding prose spans stay at the default
  /// (non-bold) style. When [repoOwner] is `null`, falls back to the
  /// previous owner-less text as a single plain span — no bold span, no
  /// empty placeholder.
  ///
  /// The trailing prose after the owner name has THREE shapes:
  /// - [_accountMismatch]: names both accounts and explains the active one
  ///   must be switched first, since `gh auth refresh` cannot target a
  ///   different account (see [_accountMismatchSpans]).
  /// - No mismatch, [GhScopeStatus.missing]/[GhScopeStatus.checkFailed] —
  ///   where `gh` is already running and only the scope is missing — keeps
  ///   the original "melde dich mit einem Account an, der Loeschrechte hat"
  ///   call-to-action.
  /// - No mismatch, [GhScopeStatus.cliUnavailable] — where `gh` isn't even
  ///   installed/logged in yet — that account-specific call-to-action would
  ///   be premature and contradictory, so the sentence stays neutral
  ///   ("Dieses Repository gehoert zu **{owner}**.") and the actual
  ///   instruction comes from [_cliUnavailableBody] / the `gh auth login`
  ///   hint that follows.
  List<TextSpan> _bodySpans(AppColors colors) {
    final proseStyle = TextStyle(color: colors.textSec, fontSize: 13);
    final owner = repoOwner;

    if (owner == null) {
      return [TextSpan(text: _bodyTextFallback, style: proseStyle)];
    }

    if (_accountMismatch) {
      return _accountMismatchSpans(owner, activeAccount!);
    }

    final TextSpan trailingSpan = status == GhScopeStatus.cliUnavailable
        ? const TextSpan(text: '. ')
        : const TextSpan(
            text:
                ' — melde dich im Terminal mit einem Account an, der '
                'Loeschrechte fuer dieses Repo hat. ',
          );

    return [
      const TextSpan(text: 'Dieses Repository gehoert zu '),
      TextSpan(
        text: owner,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailingSpan,
      TextSpan(text: _bodyTextFallback),
    ];
  }

  /// Body spans for the account-mismatch case
  /// (2026-07-22-gh-auth-refresh-wrong-account): names both the repo
  /// [owner] and the currently [active] `gh` account, explains that the
  /// right account must be activated first (since `gh auth refresh`
  /// structurally cannot refresh a different account's credentials — see
  /// `gh auth refresh --help`), and adds an informational switch-back hint
  /// (`gh auth switch --user <active>`) for after the scope is granted —
  /// stated as a hint only, never executed automatically.
  List<TextSpan> _accountMismatchSpans(String owner, String active) {
    return [
      const TextSpan(text: 'Dieses Repository gehoert '),
      TextSpan(
        text: owner,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(text: ', der aktive GitHub-CLI-Account ist aber '),
      TextSpan(
        text: active,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(text: '. Melde dich im Browser als '),
      TextSpan(
        text: owner,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(
        text:
            ' an — der Terminal-Button startet dafuer "gh auth login -s '
            'delete_repo". Danach kannst du mit "gh auth switch --user ',
      ),
      TextSpan(
        text: active,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const TextSpan(text: '" wieder zu deinem vorherigen Account wechseln.'),
    ];
  }

  void _dismiss(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _onActionPressed(BuildContext context) {
    if (_accountMismatch) {
      onOpenTerminalLogin?.call();
    } else {
      onOpenTerminal();
    }
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
          Text.rich(
            TextSpan(
              style: TextStyle(color: colors.textSec, fontSize: 13),
              children: _bodySpans(colors),
            ),
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
