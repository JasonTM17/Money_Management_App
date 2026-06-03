import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: isDark ? 0.04 : 0.28),
                Colors.transparent,
              ],
              stops: [
                _controller.value - 0.3 < 0 ? 0 : _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3 > 1 ? 1 : _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 40;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        ShimmerBox(height: 140, borderRadius: 16, width: width),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ShimmerBox(
                height: 98,
                borderRadius: 14,
                width: (width - 12) / 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShimmerBox(
                height: 98,
                borderRadius: 14,
                width: (width - 12) / 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ShimmerBox(height: 220, borderRadius: 16, width: width),
        const SizedBox(height: 20),
        ShimmerBox(height: 18, borderRadius: 6, width: 160),
        const SizedBox(height: 14),
        ...List.generate(4, (_) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerBox(height: 72, borderRadius: 14, width: width),
          );
        }),
      ],
    );
  }
}
