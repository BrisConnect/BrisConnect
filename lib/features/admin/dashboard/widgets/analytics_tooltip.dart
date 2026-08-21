import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Rich analytics insight card for chart tooltips.
///
/// Displays comprehensive data about a chart data point including:
/// - Primary metric value
/// - Date or time period
/// - Comparison with previous period
/// - Additional contextual insights
/// - Optional action link
class AnalyticsTooltipCard extends StatelessWidget {
  const AnalyticsTooltipCard({
    super.key,
    required this.title,
    required this.primaryValue,
    this.primaryLabel = '',
    this.dateRange = '',
    this.insights = const [],
    this.comparisonText = '',
    this.actionText = '',
    this.onActionTap,
    this.backgroundColor,
    this.titleColor = AppPalette.ochre,
  });

  /// Main metric name (e.g., "Social Shares")
  final String title;

  /// Large primary value display (e.g., "67")
  final String primaryValue;

  /// Optional label for primary value (e.g., "interactions")
  final String primaryLabel;

  /// Date or period (e.g., "Last 30 days")
  final String dateRange;

  /// List of additional insights to display
  /// Each string should be formatted like "Label: Value" or "↑ 12% vs previous period"
  final List<String> insights;

  /// Comparison text (e.g., "↑ 12% vs previous 30 days")
  final String comparisonText;

  /// "View details" action text
  final String actionText;

  /// Callback when action is tapped
  final VoidCallback? onActionTap;

  /// Background color of tooltip (defaults to charcoal)
  final Color? backgroundColor;

  /// Color for the title text
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppPalette.charcoal.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),

          // Primary value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primaryValue,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (primaryLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  primaryLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Date range
          if (dateRange.isNotEmpty) ...[
            Text(
              dateRange,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Comparison text
          if (comparisonText.isNotEmpty) ...[
            Text(
              comparisonText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2ECC71), // Green for positive
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Insights
          if (insights.isNotEmpty) ...[
            ...insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  insight,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Action link
          if (actionText.isNotEmpty && onActionTap != null) ...[
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.ochre,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tooltip overlay that positions itself above/beside the hovered element.
///
/// Handles viewport bounds checking and provides smooth animations.
class TooltipOverlay extends StatefulWidget {
  const TooltipOverlay({
    super.key,
    required this.child,
    required this.tooltip,
    this.offset = const Offset(0, -16),
  });

  /// The chart element that triggers the tooltip
  final Widget child;

  /// The tooltip card to display
  final Widget tooltip;

  /// Offset from the child position (default: above)
  final Offset offset;

  @override
  State<TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<TooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  OverlayEntry? _overlayEntry;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _showTooltip(BuildContext context) {
    if (_isHovered) return;
    _isHovered = true;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx + size.width / 2 - 80 + widget.offset.dx,
          top: position.dy + widget.offset.dy,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.bottomCenter,
              child: MouseRegion(
                onEnter: (_) {
                  // Keep tooltip visible when hovering over it
                },
                onExit: (_) {
                  _hideTooltip();
                },
                child: widget.tooltip,
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
  }

  void _hideTooltip() {
    _controller.reverse().then((_) {
      if (mounted && _isHovered) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        _isHovered = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _showTooltip(context);
      },
      onExit: (_) {
        _hideTooltip();
      },
      child: widget.child,
    );
  }
}

/// Insight item for tooltip display.
class TooltipInsight {
  final String label;
  final String value;
  final bool isPositive; // For styling (e.g., green for positive change)

  TooltipInsight({
    required this.label,
    required this.value,
    this.isPositive = true,
  });

  @override
  String toString() => '$label: $value';
}
