import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Toast types with associated icons and colors.
enum ToastType {
  success(Icons.check_circle_rounded),
  error(Icons.error_rounded),
  warning(Icons.warning_rounded),
  info(Icons.info_rounded),
  neutral(null);

  final IconData? icon;
  const ToastType(this.icon);
}

class Toast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  // Animation duration constants
  static const _entranceDuration = Duration(milliseconds: 350);
  static const _exitDuration = Duration(milliseconds: 250);

  /// Shows a toast with optional type, action, and styling.
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.neutral,
    Duration duration = const Duration(seconds: 4),
    String actionLabel = '',
    VoidCallback? onAction,
  }) {
    _dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);
    final hasAction = actionLabel.isNotEmpty && onAction != null;

    _currentEntry = OverlayEntry(
      builder: (_) => _AnimatedToast(
        message: message,
        type: type,
        actionLabel: hasAction ? actionLabel : null,
        onAction: hasAction
            ? () {
                _dismiss();
                onAction();
              }
            : null,
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    _timer = Timer(duration, _dismiss);
  }

  /// Convenience method for success toasts.
  static void success(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  /// Convenience method for error toasts.
  static void error(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  /// Convenience method for warning toasts.
  static void warning(BuildContext context, String message) {
    show(context, message: message, type: ToastType.warning);
  }

  /// Convenience method for info toasts.
  static void info(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;

    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AnimatedToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _AnimatedToast({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Toast._entranceDuration,
      reverseDuration: Toast._exitDuration,
    );

    // Slide from bottom with spring-like curve
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Fade in/out
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _ToastContent(
            message: widget.message,
            type: widget.type,
            actionLabel: widget.actionLabel,
            onAction: widget.onAction,
            onDismiss: widget.onDismiss,
          ),
        ),
      ),
    );
  }
}

class _ToastContent extends StatelessWidget {
  final String message;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  // Glassmorphism constants
  static const _blurSigma = 12.0;
  static const _backgroundOpacity = 0.85;
  static const _borderOpacity = 0.2;

  const _ToastContent({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasAction = actionLabel != null && onAction != null;

    final accentColor = _getAccentColor(colorScheme);
    final backgroundColor = colorScheme.inverseSurface;
    final textColor = colorScheme.onInverseSurface;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: _backgroundOpacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor?.withValues(alpha: _borderOpacity) ??
                  colorScheme.outline.withValues(alpha: _borderOpacity),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (accentColor ?? colorScheme.shadow).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Icon with accent color
                    if (type.icon != null) ...[
                      _AnimatedIcon(
                        icon: type.icon!,
                        color: accentColor ?? textColor,
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Message
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Action button
                    if (hasAction) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor ?? colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color? _getAccentColor(ColorScheme colorScheme) {
    return switch (type) {
      ToastType.success => const Color(0xFF6EC6B8), // Teal-mint
      ToastType.error => colorScheme.error,
      ToastType.warning => const Color(0xFFCB8F7A), // Muted rust (same as error)
      ToastType.info => const Color(0xFFA8B4D4), // Soft lavender-blue
      ToastType.neutral => null,
    };
  }
}

/// Animated icon with a subtle scale-in effect.
class _AnimatedIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _AnimatedIcon({required this.icon, required this.color});

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    // Slight delay before icon pops in
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          size: 18,
          color: widget.color,
        ),
      ),
    );
  }
}
