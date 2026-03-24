import 'package:flutter/material.dart';

/// Data for a single segment in the category bar.
class CategorySegment {
  final String categoryId;
  final String categoryName;
  final int totalMinor;
  final Color color;
  final double percentage;

  const CategorySegment({
    required this.categoryId,
    required this.categoryName,
    required this.totalMinor,
    required this.color,
    required this.percentage,
  });
}

/// Single horizontal bar divided into colored segments by category proportion.
///
/// An elegant alternative to pie charts that works well on mobile.
/// Shows category distribution as proportional segments in a single bar.
class SegmentedCategoryBar extends StatelessWidget {
  final List<CategorySegment> segments;
  final double height;
  final double borderRadius;

  static const double _dividerWidth = 1.0;

  const SegmentedCategoryBar({
    super.key,
    required this.segments,
    this.height = 24.0,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return SizedBox(height: height);
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final dividerCount = segments.length - 1;
            final availableWidth = totalWidth - (dividerCount * _dividerWidth);

            return Row(
              children: _buildSegments(availableWidth, colorScheme),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSegments(double availableWidth, ColorScheme colorScheme) {
    final widgets = <Widget>[];

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];

      // Convert percentage to flex factor (scale to avoid rounding errors)
      // Higher precision: multiply by 10000 to preserve decimal precision
      final flexFactor = (segment.percentage * 10000).round();

      widgets.add(
        Expanded(
          flex: flexFactor > 0 ? flexFactor : 1,
          child: Container(
            height: height,
            color: segment.color,
          ),
        ),
      );

      // Add divider between segments (but not after the last one)
      if (i < segments.length - 1) {
        widgets.add(
          Container(
            width: _dividerWidth,
            height: height,
            color: colorScheme.surfaceContainerLowest,
          ),
        );
      }
    }

    return widgets;
  }
}
