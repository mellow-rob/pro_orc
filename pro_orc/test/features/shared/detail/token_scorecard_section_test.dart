import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/features/shared/detail/token_scorecard_section.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// FR-004/FR-005/FR-007: TokenScorecardSection surfaces the already-computed
/// per-project token data (input/output/cache/session-count/last-activity)
/// as compact stat tiles, with an explicit "keine Daten" state when no
/// session carries usage data. Aggregation is all-time (no time filter).
void main() {
  const projectPath = '/tmp/my-project';

  Future<void> pumpSection(
    WidgetTester tester,
    ProjectSessionData sessionData,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectSessionsProvider(
            projectPath,
          ).overrideWith((ref) async => sessionData),
        ],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
          home: Builder(
            builder: (context) {
              final colors = Theme.of(context).extension<AppColors>()!;
              return Scaffold(
                body: TokenScorecardSection(
                  projectPath: projectPath,
                  colors: colors,
                  accent: colors.cyan,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders aggregated input/output/cache tokens, session count, and '
    'last activity when sessions carry usage data',
    (tester) async {
      final sessions = [
        SessionInfo(
          id: 's1',
          path: '/tmp/s1.jsonl',
          lastActivity: DateTime(2026, 7, 15, 10, 30),
          isActive: false,
          inputTokens: 1000,
          outputTokens: 500,
          cacheTokens: 200,
        ),
        SessionInfo(
          id: 's2',
          path: '/tmp/s2.jsonl',
          lastActivity: DateTime(2026, 7, 10, 8, 0),
          isActive: false,
          inputTokens: 2000,
          outputTokens: 1000,
          cacheTokens: 300,
        ),
      ];
      // Sorted descending by lastActivity, matching SessionReader's contract.
      sessions.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));

      await pumpSection(tester, ProjectSessionData(sessions: sessions));

      // Aggregated (all-time, both sessions) totals: input 3000, output
      // 1500, cache 500 — formatted via the existing formatTokenCount helper.
      expect(find.text(formatTokenCount(3000)), findsOneWidget);
      expect(find.text(formatTokenCount(1500)), findsOneWidget);
      expect(find.text(formatTokenCount(500)), findsOneWidget);

      // Session count.
      expect(find.text('2'), findsOneWidget);

      // Last activity uses the most recent session's timestamp.
      expect(find.textContaining('2026-07-15'), findsOneWidget);

      // Never the removed SizedBox.shrink()-style silence.
      expect(
        find.text('Keine Daten zur Token-Nutzung vorhanden.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'shows explicit "keine Daten" state when no session has usage data '
    '(sawUsage == false for all sessions)',
    (tester) async {
      final sessions = [
        SessionInfo(
          id: 's1',
          path: '/tmp/s1.jsonl',
          lastActivity: DateTime(2026, 7, 15, 10, 30),
          isActive: false,
          // No inputTokens/outputTokens/cacheTokens set → hasTokenEstimate
          // is false, matching the sawUsage == false log convention.
        ),
      ];

      await pumpSection(tester, ProjectSessionData(sessions: sessions));

      expect(
        find.text('Keine Daten zur Token-Nutzung vorhanden.'),
        findsOneWidget,
      );
      // Must not render misleading zero values instead.
      expect(find.text('0'), findsNothing);
    },
  );

  testWidgets(
    'shows the "keine Daten" state for a project with no sessions at all',
    (tester) async {
      await pumpSection(tester, ProjectSessionData.empty);

      expect(
        find.text('Keine Daten zur Token-Nutzung vorhanden.'),
        findsOneWidget,
      );
    },
  );
}
