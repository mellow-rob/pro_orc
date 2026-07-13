import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/features/shared/detail/section_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Expandable description section — short texts always selectable,
/// long texts (>5 lines) collapsed by default with expand/collapse toggle.
class DescriptionSection extends StatefulWidget {
  const DescriptionSection({
    super.key,
    required this.colors,
    required this.accent,
    required this.description,
  });

  final AppColors colors;
  final Color accent;
  final String description;

  @override
  State<DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<DescriptionSection> {
  bool _expanded = false;

  TextStyle get _textStyle =>
      TextStyle(color: widget.colors.textSec, fontSize: 14, height: 1.6);

  bool _needsExpansion(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.description, style: _textStyle),
      maxLines: 5,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      colors: widget.colors,
      accent: widget.accent,
      title: 'BESCHREIBUNG',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needsToggle = _needsExpansion(constraints.maxWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!needsToggle || _expanded)
                SelectableText(widget.description, style: _textStyle)
              else
                Text(
                  widget.description,
                  style: _textStyle,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              if (needsToggle)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ExpandToggleButton(
                    expanded: _expanded,
                    colors: widget.colors,
                    accent: widget.accent,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Toggle button with hover effect for expand/collapse sections.
class _ExpandToggleButton extends StatefulWidget {
  const _ExpandToggleButton({
    required this.expanded,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final bool expanded;
  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_ExpandToggleButton> createState() => _ExpandToggleButtonState();
}

class _ExpandToggleButtonState extends State<_ExpandToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? widget.accent : widget.colors.textDim;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.expanded
                  ? LucideIcons.chevronDown100
                  : LucideIcons.chevronRight100,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              widget.expanded ? 'Weniger anzeigen' : 'Mehr anzeigen',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
