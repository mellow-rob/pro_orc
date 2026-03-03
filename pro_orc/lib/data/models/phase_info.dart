import 'package:pro_orc/data/models/phase_status.dart';

/// Represents a single phase from a project's ROADMAP.md.
class PhaseInfo {
  final int number;
  final String name;
  final PhaseStatus status;
  final int plansCompleted;
  final int plansTotal;

  const PhaseInfo({
    required this.number,
    required this.name,
    required this.status,
    this.plansCompleted = 0,
    this.plansTotal = 0,
  });
}
