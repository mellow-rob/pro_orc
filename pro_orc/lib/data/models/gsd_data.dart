import 'package:pro_orc/data/models/phase_info.dart';

class GsdData {
  final String? status; // 'research'|'planning'|'building'|'paused'|'done'|'archived'
  final String? currentPhase; // e.g. "3 of 5 (API Layer)"
  final String? nextStep;
  final int? phaseProgress; // 0-100
  final String? notionUrl;
  final String? description;
  final int? phasesCompleted;
  final int? phasesTotal;
  final int? plansCompleted;
  final int? plansTotal;
  final String? version;
  final List<PhaseInfo>? phases;
  final List<String>? decisions;

  const GsdData({
    this.status,
    this.currentPhase,
    this.nextStep,
    this.phaseProgress,
    this.notionUrl,
    this.description,
    this.phasesCompleted,
    this.phasesTotal,
    this.plansCompleted,
    this.plansTotal,
    this.version,
    this.phases,
    this.decisions,
  });

  static const empty = GsdData();

  bool get isEmpty =>
      status == null &&
      currentPhase == null &&
      phaseProgress == null &&
      phasesTotal == null &&
      plansTotal == null;
}
