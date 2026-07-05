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

/// One project's contribution to a multi-project collaboration graph: the
/// project's identity plus the agent and skill names it is connected to.
///
/// Used as the input to [MultiCollaborationGraphData.buildAll] so the caller
/// (the full network view) can assemble per-project agent/skill lists however
/// it likes (local `.claude/` scan + `usedAgents`) without this model needing
/// to know about `ProjectModel` or the scanner.
class ProjectGraphInput {
  final String projectId;
  final String projectName;

  /// Agent names this project uses (local + referenced), de-duplicated by
  /// [MultiCollaborationGraphData.buildAll].
  final List<String> agentNames;

  /// Skill names this project uses, de-duplicated by
  /// [MultiCollaborationGraphData.buildAll].
  final List<String> skillNames;

  const ProjectGraphInput({
    required this.projectId,
    required this.projectName,
    this.agentNames = const [],
    this.skillNames = const [],
  });
}

/// A multi-project collaboration graph: every project is its own node, and
/// each distinct agent/skill is a single shared node that connects to every
/// project referencing it. Shared agents/skills therefore bridge multiple
/// projects visually — the whole point of the full network view (M7 AD-2).
///
/// Reuses [GraphNode]/[GraphEdge]/[GraphNodeKind] from the mini-graph so the
/// same painter/label widgets render both. Agent and skill node ids share the
/// `agent:`/`skill:` namespace with the mini-graph, guaranteeing a given
/// agent name maps to exactly one node no matter how many projects use it.
class MultiCollaborationGraphData {
  final List<GraphNode> projectNodes;
  final List<GraphNode> agentNodes;
  final List<GraphNode> skillNodes;
  final List<GraphEdge> edges;

  const MultiCollaborationGraphData({
    required this.projectNodes,
    required this.agentNodes,
    required this.skillNodes,
    required this.edges,
  });

  bool get isEmpty => projectNodes.isEmpty;

  /// All nodes (projects, then agents, then skills) in a stable order.
  List<GraphNode> get allNodes => [...projectNodes, ...agentNodes, ...skillNodes];

  /// Builds a deduplicated multi-project graph from per-project [inputs].
  ///
  /// A given agent/skill name produces exactly one shared node regardless of
  /// how many projects reference it; each project→agent and project→skill
  /// reference produces one edge. Duplicate references within a single project
  /// (same name listed twice) collapse to a single edge. Empty [inputs]
  /// yields an empty graph.
  factory MultiCollaborationGraphData.buildAll(List<ProjectGraphInput> inputs) {
    final projectNodes = <GraphNode>[];
    final agentNodeById = <String, GraphNode>{};
    final skillNodeById = <String, GraphNode>{};
    final edges = <GraphEdge>[];
    final seenEdges = <String>{};

    void addEdge(String fromId, String toId) {
      final key = '$fromId->$toId';
      if (seenEdges.add(key)) {
        edges.add(GraphEdge(fromId: fromId, toId: toId));
      }
    }

    for (final input in inputs) {
      final projectNode = GraphNode(
        id: 'project:${input.projectId}',
        label: input.projectName,
        kind: GraphNodeKind.project,
      );
      projectNodes.add(projectNode);

      for (final name in input.agentNames) {
        if (name.isEmpty) continue;
        final id = 'agent:$name';
        agentNodeById.putIfAbsent(
          id,
          () => GraphNode(id: id, label: name, kind: GraphNodeKind.agent),
        );
        addEdge(projectNode.id, id);
      }

      for (final name in input.skillNames) {
        if (name.isEmpty) continue;
        final id = 'skill:$name';
        skillNodeById.putIfAbsent(
          id,
          () => GraphNode(id: id, label: name, kind: GraphNodeKind.skill),
        );
        addEdge(projectNode.id, id);
      }
    }

    return MultiCollaborationGraphData(
      projectNodes: projectNodes,
      agentNodes: agentNodeById.values.toList(),
      skillNodes: skillNodeById.values.toList(),
      edges: edges,
    );
  }
}
