import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/projects/type_badge.dart';
import 'package:pro_orc/theme/n3_colors.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows "Code" label for ProjectType.code', (tester) async {
    await tester.pumpWidget(_wrap(const TypeBadge(type: ProjectType.code)));

    expect(find.text('Code'), findsOneWidget);
  });

  testWidgets('shows "Research" label for ProjectType.research', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const TypeBadge(type: ProjectType.research)));

    expect(find.text('Research'), findsOneWidget);
  });

  testWidgets('uses cyan accent for code, fuchsia for research', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const TypeBadge(type: ProjectType.code)));
    final codeText = tester.widget<Text>(find.text('Code'));
    final codeColor = codeText.style!.color;

    await tester.pumpWidget(_wrap(const TypeBadge(type: ProjectType.research)));
    final researchText = tester.widget<Text>(find.text('Research'));
    final researchColor = researchText.style!.color;

    expect(codeColor, isNot(equals(researchColor)));
  });
}
