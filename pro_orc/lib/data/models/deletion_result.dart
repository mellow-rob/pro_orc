import 'package:pro_orc/data/models/external_resource.dart';

/// Why a resource deletion succeeded or failed.
///
/// [alreadyDeleted] is a SUCCESS outcome (idempotent — the desired end
/// state, the resource being gone, is already true), not a failure
/// (FR-017). [missingScope] and [notAuthenticated] are deliberately
/// distinct failure reasons (FR-009) even though both stem from the `gh`
/// CLI's auth state — a scope error is user-fixable in one command
/// (`gh auth refresh -s delete_repo`), while a plain auth failure is not.
enum DeletionOutcome {
  /// The resource was actively deleted by this run.
  success,

  /// The CLI reported the target does not exist — treated as success
  /// because the user's desired end state (resource gone) already holds.
  alreadyDeleted,

  /// The CLI call failed because the current login has no valid session
  /// at all (distinct from [missingScope]).
  notAuthenticated,

  /// The `gh` CLI call failed specifically because the token lacks the
  /// `delete_repo` OAuth scope. Distinct from [notAuthenticated] so the
  /// user gets the specific, one-command fix rather than a generic
  /// "please log in" message.
  missingScope,

  /// Any other failure not covered by the reasons above.
  genericFailure,
}

/// Human-readable German reason text for each [DeletionOutcome].
///
/// [genericFailure] has no fixed text here — callers append the CLI's
/// stderr gist to `_genericFailurePrefix` themselves (see
/// [DeletionResult.genericFailure]) since the detail is call-specific.
const _genericFailurePrefix = 'Fehlgeschlagen';

String _reasonFor(DeletionOutcome outcome) {
  switch (outcome) {
    case DeletionOutcome.success:
      return 'Erfolgreich geloescht';
    case DeletionOutcome.alreadyDeleted:
      return 'war bereits geloescht';
    case DeletionOutcome.notAuthenticated:
      return 'nicht authentifiziert';
    case DeletionOutcome.missingScope:
      return 'Berechtigung fehlt — gh auth refresh -s delete_repo ausfuehren';
    case DeletionOutcome.genericFailure:
      return _genericFailurePrefix;
  }
}

/// Immutable per-resource deletion outcome, shown as one row in the
/// dialog's result report (FR-009).
class DeletionResult {
  /// The URI of the resource this result is for — matches
  /// [ExternalResource.uri] so the dialog can map results back to rows.
  final String uri;

  final ExternalResourceType type;

  /// True for [DeletionOutcome.success] and [DeletionOutcome.alreadyDeleted]
  /// — both render as a success row (FR-017: already-deleted is NOT a
  /// failure).
  final bool succeeded;

  final DeletionOutcome outcome;

  /// Human-readable German reason shown in the result row. For
  /// [DeletionOutcome.genericFailure] this includes the CLI's stderr gist;
  /// for every other outcome it is the fixed text from [_reasonFor].
  final String reason;

  const DeletionResult._({
    required this.uri,
    required this.type,
    required this.succeeded,
    required this.outcome,
    required this.reason,
  });

  factory DeletionResult.success(String uri, ExternalResourceType type) {
    return DeletionResult._(
      uri: uri,
      type: type,
      succeeded: true,
      outcome: DeletionOutcome.success,
      reason: _reasonFor(DeletionOutcome.success),
    );
  }

  factory DeletionResult.alreadyDeleted(String uri, ExternalResourceType type) {
    return DeletionResult._(
      uri: uri,
      type: type,
      succeeded: true,
      outcome: DeletionOutcome.alreadyDeleted,
      reason: _reasonFor(DeletionOutcome.alreadyDeleted),
    );
  }

  factory DeletionResult.notAuthenticated(
    String uri,
    ExternalResourceType type,
  ) {
    return DeletionResult._(
      uri: uri,
      type: type,
      succeeded: false,
      outcome: DeletionOutcome.notAuthenticated,
      reason: _reasonFor(DeletionOutcome.notAuthenticated),
    );
  }

  factory DeletionResult.missingScope(String uri, ExternalResourceType type) {
    return DeletionResult._(
      uri: uri,
      type: type,
      succeeded: false,
      outcome: DeletionOutcome.missingScope,
      reason: _reasonFor(DeletionOutcome.missingScope),
    );
  }

  /// [stderrGist] is a short, already-trimmed excerpt of the CLI's stderr
  /// output appended to the fixed prefix so the user has some concrete
  /// detail without a raw stack dump.
  factory DeletionResult.genericFailure(
    String uri,
    ExternalResourceType type,
    String stderrGist,
  ) {
    final trimmed = stderrGist.trim();
    final reason = trimmed.isEmpty
        ? _reasonFor(DeletionOutcome.genericFailure)
        : '${_reasonFor(DeletionOutcome.genericFailure)}: $trimmed';
    return DeletionResult._(
      uri: uri,
      type: type,
      succeeded: false,
      outcome: DeletionOutcome.genericFailure,
      reason: reason,
    );
  }
}
