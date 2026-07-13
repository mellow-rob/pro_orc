import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  const colors = AppColors.dark;

  group('ProjectTypeVisuals', () {
    test('code accent is cyan', () {
      expect(ProjectType.code.accent(colors), colors.cyan);
    });

    test('research accent is fuchsia', () {
      expect(ProjectType.research.accent(colors), colors.fuch);
    });

    test('code icon is codeXml', () {
      expect(ProjectType.code.icon, LucideIcons.codeXml100);
    });

    test('research icon is beaker', () {
      expect(ProjectType.research.icon, LucideIcons.beaker100);
    });

    test('code moveTarget is research', () {
      expect(ProjectType.code.moveTarget, ProjectType.research);
    });

    test('research moveTarget is code', () {
      expect(ProjectType.research.moveTarget, ProjectType.code);
    });
  });
}
