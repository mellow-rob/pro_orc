/// The kind of node in a project-focused collaboration mini-graph.
enum GraphNodeKind { project, agent, skill }

/// A single node in the collaboration graph (a project, agent, or skill).
class GraphNode {
  final String id;
  final String label;
  final GraphNodeKind kind;

  /// True for agents/skills that live in the project's own `.claude/`
  /// directory, as opposed to a globally-defined GSD agent referenced by
  /// name only (from `ProjectModel.usedAgents`).
  final bool isLocal;

  const GraphNode({
    required this.id,
    required this.label,
    required this.kind,
    this.isLocal = false,
  });
}

/// A directed edge from the project node to an agent/skill node.
class GraphEdge {
  final String fromId;
  final String toId;

  const GraphEdge({required this.fromId, required this.toId});
}

/// Prepared node/edge data for a project-focused collaboration mini-graph:
/// the project itself, its local agents, its local skills, and the GSD
/// agents it references by name (`ProjectModel.usedAgents`).
class CollaborationGraphData {
  final GraphNode projectNode;
  final List<GraphNode> agentNodes;
  final List<GraphNode> skillNodes;
  final List<GraphEdge> edges;

  const CollaborationGraphData({
    required this.projectNode,
    required this.agentNodes,
    required this.skillNodes,
    required this.edges,
  });

  bool get isEmpty => agentNodes.isEmpty && skillNodes.isEmpty;

  /// Builds graph data for [projectId]/[projectName] from its local agent
  /// names, local skill names, and the GSD agent names it references
  /// (`usedAgents`). Local names always win over a same-named used-agent
  /// entry to avoid duplicate nodes.
  factory CollaborationGraphData.build({
    required String projectId,
    required String projectName,
    required List<String> localAgentNames,
    required List<String> localSkillNames,
    required List<String> usedAgentNames,
  }) {
    final projectNode = GraphNode(
      id: 'project:$projectId',
      label: projectName,
      kind: GraphNodeKind.project,
    );

    final agentNodes = <GraphNode>[
      for (final name in localAgentNames)
        GraphNode(
          id: 'agent:$name',
          label: name,
          kind: GraphNodeKind.agent,
          isLocal: true,
        ),
      for (final name in usedAgentNames.toSet().difference(localAgentNames.toSet()))
        GraphNode(
          id: 'agent:$name',
          label: name,
          kind: GraphNodeKind.agent,
          isLocal: false,
        ),
    ];

    final skillNodes = [
      for (final name in localSkillNames)
        GraphNode(
          id: 'skill:$name',
          label: name,
          kind: GraphNodeKind.skill,
          isLocal: true,
        ),
    ];

    final edges = [
      for (final node in agentNodes) GraphEdge(fromId: projectNode.id, toId: node.id),
      for (final node in skillNodes) GraphEdge(fromId: projectNode.id, toId: node.id),
    ];

    return CollaborationGraphData(
      projectNode: projectNode,
      agentNodes: agentNodes,
      skillNodes: skillNodes,
      edges: edges,
    );
  }
}
