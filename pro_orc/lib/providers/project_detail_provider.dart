import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_model.dart';

/// Currently open project detail view, embedded inside `ShellScreen`'s
/// content area (replaces the old full-screen `Navigator.push` route).
///
/// `null` means no detail view is open — the shell shows the normal
/// tab `IndexedStack`. Setting a non-null value swaps the shell's content
/// area for the detail view while the side navigation stays visible and
/// interactive; picking another tab while a detail view is open closes it
/// and switches tabs in one step (see `_ShellScreenState._onSelectTab`).
class OpenProjectDetailNotifier extends Notifier<ProjectModel?> {
  @override
  ProjectModel? build() => null;

  void open(ProjectModel project) => state = project;

  void close() => state = null;
}

final openProjectDetailProvider =
    NotifierProvider<OpenProjectDetailNotifier, ProjectModel?>(
  OpenProjectDetailNotifier.new,
);
