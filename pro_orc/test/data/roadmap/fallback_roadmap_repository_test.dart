import 'package:test/test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/roadmap/fallback_roadmap_repository.dart';
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';

/// Fake tier stub used to test ONLY [FallbackRoadmapRepository]'s
/// composition/ordering logic (FR-002) in isolation — legitimate use of a
/// test double here since the behavior under test is the orchestrator's
/// control flow, not any real tier's parsing/network behavior.
class _StubRepository implements RoadmapRepository {
  _StubRepository(this._result);

  final RoadmapResult _result;
  int callCount = 0;

  @override
  Future<RoadmapResult> resolve(String slug, String projectPath) async {
    callCount++;
    return _result;
  }
}

const _nonEmptyLocal = RoadmapData(
  milestones: [RoadmapMilestone(name: 'M1', status: 'done')],
);
const _nonEmptyBrain = RoadmapData(
  milestones: [RoadmapMilestone(name: 'M2', status: 'in_progress')],
);
const _nonEmptyVault = RoadmapData(
  milestones: [RoadmapMilestone(name: 'M3', status: 'planning')],
);

void main() {
  group('FallbackRoadmapRepository ordering (FR-002)', () {
    test(
      'returns local result and never queries brain/vault when local is usable',
      () async {
        final local = _StubRepository(
          const RoadmapResult(
            data: _nonEmptyLocal,
            source: RoadmapSource.local,
          ),
        );
        final brain = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.brain,
          ),
        );
        final vault = _StubRepository(
          const RoadmapResult(
            data: _nonEmptyVault,
            source: RoadmapSource.vault,
          ),
        );

        final repo = FallbackRoadmapRepository(
          local: local,
          brain: brain,
          vault: vault,
        );
        final result = await repo.resolve('slug', '/path');

        expect(result.source, RoadmapSource.local);
        expect(local.callCount, 1);
        expect(brain.callCount, 0);
        expect(vault.callCount, 0);
      },
    );

    test('falls through to brain when local is empty', () async {
      final local = _StubRepository(
        const RoadmapResult(
          data: RoadmapData.empty,
          source: RoadmapSource.local,
        ),
      );
      final brain = _StubRepository(
        const RoadmapResult(data: _nonEmptyBrain, source: RoadmapSource.brain),
      );
      final vault = _StubRepository(
        const RoadmapResult(data: _nonEmptyVault, source: RoadmapSource.vault),
      );

      final repo = FallbackRoadmapRepository(
        local: local,
        brain: brain,
        vault: vault,
      );
      final result = await repo.resolve('slug', '/path');

      expect(result.source, RoadmapSource.brain);
      expect(local.callCount, 1);
      expect(brain.callCount, 1);
      expect(vault.callCount, 0);
    });

    test(
      'falls through to vault when local and brain are both empty',
      () async {
        final local = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.local,
          ),
        );
        final brain = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.brain,
          ),
        );
        final vault = _StubRepository(
          const RoadmapResult(
            data: _nonEmptyVault,
            source: RoadmapSource.vault,
          ),
        );

        final repo = FallbackRoadmapRepository(
          local: local,
          brain: brain,
          vault: vault,
        );
        final result = await repo.resolve('slug', '/path');

        expect(result.source, RoadmapSource.vault);
        expect(local.callCount, 1);
        expect(brain.callCount, 1);
        expect(vault.callCount, 1);
      },
    );

    test(
      'returns empty vault-sourced result when all three tiers are empty',
      () async {
        final local = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.local,
          ),
        );
        final brain = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.brain,
          ),
        );
        final vault = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.vault,
          ),
        );

        final repo = FallbackRoadmapRepository(
          local: local,
          brain: brain,
          vault: vault,
        );
        final result = await repo.resolve('slug', '/path');

        expect(result.data.isEmpty, isTrue);
        expect(result.source, RoadmapSource.vault);
      },
    );

    test(
      'uses the built-in stub vault tier when none is injected (Wave 1 default)',
      () async {
        final local = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.local,
          ),
        );
        final brain = _StubRepository(
          const RoadmapResult(
            data: RoadmapData.empty,
            source: RoadmapSource.brain,
          ),
        );

        final repo = FallbackRoadmapRepository(local: local, brain: brain);
        final result = await repo.resolve('slug', '/path');

        expect(result.data.isEmpty, isTrue);
        expect(result.source, RoadmapSource.vault);
      },
    );
  });
}
