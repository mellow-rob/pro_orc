import 'package:test/test.dart';

import 'package:pro_orc/data/models/collaboration_graph.dart';

void main() {
  group('CollaborationGraphData.build', () {
    test('builds a project node with the given id and name', () {
      final data = CollaborationGraphData.build(
        projectId: 'my-project',
        projectName: 'My Project',
        localAgentNames: const [],
        localSkillNames: const [],
        usedAgentNames: const [],
      );

      expect(data.projectNode.id, 'project:my-project');
      expect(data.projectNode.label, 'My Project');
      expect(data.projectNode.kind, GraphNodeKind.project);
    });

    test('creates a local agent node for each local agent name', () {
      final data = CollaborationGraphData.build(
        projectId: 'p',
        projectName: 'P',
        localAgentNames: const ['niimo-qa'],
        localSkillNames: const [],
        usedAgentNames: const [],
      );

      expect(data.agentNodes, hasLength(1));
      expect(data.agentNodes.first.label, 'niimo-qa');
      expect(data.agentNodes.first.isLocal, isTrue);
    });

    test('creates a non-local agent node for each used-agent name not already local', () {
      final data = CollaborationGraphData.build(
        projectId: 'p',
        projectName: 'P',
        localAgentNames: const [],
        localSkillNames: const [],
        usedAgentNames: const ['a1-erik-executor'],
      );

      expect(data.agentNodes, hasLength(1));
      expect(data.agentNodes.first.label, 'a1-erik-executor');
      expect(data.agentNodes.first.isLocal, isFalse);
    });

    test('does not duplicate an agent that is both local and used', () {
      final data = CollaborationGraphData.build(
        projectId: 'p',
        projectName: 'P',
        localAgentNames: const ['shared-agent'],
        localSkillNames: const [],
        usedAgentNames: const ['shared-agent'],
      );

      expect(data.agentNodes, hasLength(1));
      expect(data.agentNodes.first.isLocal, isTrue);
    });

    test('creates a skill node for each local skill name', () {
      final data = CollaborationGraphData.build(
        projectId: 'p',
        projectName: 'P',
        localAgentNames: const [],
        localSkillNames: const ['my-skill'],
        usedAgentNames: const [],
      );

      expect(data.skillNodes, hasLength(1));
      expect(data.skillNodes.first.label, 'my-skill');
      expect(data.skillNodes.first.kind, GraphNodeKind.skill);
    });

    test('builds one edge from project to each agent/skill node', () {
      final data = CollaborationGraphData.build(
        projectId: 'p',
        projectName: 'P',
        localAgentNames: const ['agent-a'],
        localSkillNames: const ['skill-b'],
        usedAgentNames: const ['agent-c'],
      );

      expect(data.edges, hasLength(3));
      for (final edge in data.edges) {
        expect(edge.fromId, data.projectNode.id);
      }
      final targetIds = data.edges.map((e) => e.toId).toSet();
      expect(targetIds, {'agent:agent-a', 'skill:skill-b', 'agent:agent-c'});
    });

    test('isEmpty is true when there are no agents or skills', () {
      final data = CollaborationGraphData.build(
        projectId: 'p',
        projectName: 'P',
        localAgentNames: const [],
        localSkillNames: const [],
        usedAgentNames: const [],
      );

      expect(data.isEmpty, isTrue);
    });

    test('isEmpty is false when there is at least one agent', () {
      final data = CollaborationGraphData.build(
        projectId: 'p',
        projectName: 'P',
        localAgentNames: const ['a'],
        localSkillNames: const [],
        usedAgentNames: const [],
      );

      expect(data.isEmpty, isFalse);
    });
  });

  group('MultiCollaborationGraphData.buildAll', () {
    test('empty input yields an empty graph', () {
      final data = MultiCollaborationGraphData.buildAll(const []);

      expect(data.isEmpty, isTrue);
      expect(data.projectNodes, isEmpty);
      expect(data.agentNodes, isEmpty);
      expect(data.skillNodes, isEmpty);
      expect(data.edges, isEmpty);
    });

    test('creates one project node per input', () {
      final data = MultiCollaborationGraphData.buildAll(const [
        ProjectGraphInput(projectId: 'a', projectName: 'Alpha'),
        ProjectGraphInput(projectId: 'b', projectName: 'Beta'),
      ]);

      expect(data.projectNodes, hasLength(2));
      expect(
        data.projectNodes.map((n) => n.id).toSet(),
        {'project:a', 'project:b'},
      );
      expect(data.projectNodes.every((n) => n.kind == GraphNodeKind.project), isTrue);
    });

    test('a shared agent produces a single node connecting both projects', () {
      final data = MultiCollaborationGraphData.buildAll(const [
        ProjectGraphInput(projectId: 'a', projectName: 'Alpha', agentNames: ['shared']),
        ProjectGraphInput(projectId: 'b', projectName: 'Beta', agentNames: ['shared']),
      ]);

      // Deduplicated to exactly one shared agent node.
      expect(data.agentNodes, hasLength(1));
      expect(data.agentNodes.first.id, 'agent:shared');

      // But one edge from each project to it.
      final edgesToShared =
          data.edges.where((e) => e.toId == 'agent:shared').toList();
      expect(edgesToShared, hasLength(2));
      expect(
        edgesToShared.map((e) => e.fromId).toSet(),
        {'project:a', 'project:b'},
      );
    });

    test('deduplicates skills across projects and builds correct edges', () {
      final data = MultiCollaborationGraphData.buildAll(const [
        ProjectGraphInput(projectId: 'a', projectName: 'Alpha', skillNames: ['s1', 's2']),
        ProjectGraphInput(projectId: 'b', projectName: 'Beta', skillNames: ['s2']),
      ]);

      expect(data.skillNodes.map((n) => n.id).toSet(), {'skill:s1', 'skill:s2'});
      final edgesToS2 = data.edges.where((e) => e.toId == 'skill:s2').toList();
      expect(edgesToS2, hasLength(2));
    });

    test('collapses duplicate references within a single project to one edge', () {
      final data = MultiCollaborationGraphData.buildAll(const [
        ProjectGraphInput(
          projectId: 'a',
          projectName: 'Alpha',
          agentNames: ['dup', 'dup'],
        ),
      ]);

      expect(data.agentNodes, hasLength(1));
      expect(data.edges.where((e) => e.toId == 'agent:dup'), hasLength(1));
    });

    test('skips empty agent/skill names', () {
      final data = MultiCollaborationGraphData.buildAll(const [
        ProjectGraphInput(
          projectId: 'a',
          projectName: 'Alpha',
          agentNames: ['', 'real'],
          skillNames: [''],
        ),
      ]);

      expect(data.agentNodes.map((n) => n.id).toList(), ['agent:real']);
      expect(data.skillNodes, isEmpty);
    });

    test('allNodes returns projects, then agents, then skills', () {
      final data = MultiCollaborationGraphData.buildAll(const [
        ProjectGraphInput(
          projectId: 'a',
          projectName: 'Alpha',
          agentNames: ['ag'],
          skillNames: ['sk'],
        ),
      ]);

      expect(
        data.allNodes.map((n) => n.id).toList(),
        ['project:a', 'agent:ag', 'skill:sk'],
      );
    });
  });
}
