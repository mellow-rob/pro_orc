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
}
