import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/models/a1_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/projects/a1_badge.dart';
import 'package:pro_orc/theme/n3_colors.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
    home: Scaffold(body: child),
  );
}

ProjectModel _project({A1Data? a1}) {
  return ProjectModel(
    folderId: 'demo',
    displayName: 'demo',
    path: '/tmp/demo',
    a1: a1,
  );
}

void main() {
  testWidgets('renders nothing when project.a1 is null', (tester) async {
    await tester.pumpWidget(_wrap(A1Badge(project: _project())));

    expect(find.byType(A1Badge), findsOneWidget);
    expect(find.text('a1'), findsNothing);
  });

  testWidgets('renders nothing when project.a1 is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(A1Badge(project: _project(a1: A1Data.empty))),
    );

    expect(find.text('a1'), findsNothing);
  });

  testWidgets('renders the "a1" pill when project.a1 has data', (tester) async {
    const a1 = A1Data(
      phases: [
        A1Phase(name: 'M1', checkedTasks: 1, totalTasks: 2, planPath: 'x'),
      ],
    );
    await tester.pumpWidget(_wrap(A1Badge(project: _project(a1: a1))));

    expect(find.text('a1'), findsOneWidget);
  });
}
