import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/glass_style.dart';

/// A premium translucent bottom navigation bar with frosted glass blur,
/// animated selection pill, and smooth icon transitions.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath =
        GoRouter.of(context).routeInformationProvider.value.uri.toString();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <_NavItem>[
      _NavItem(path: '/home', icon: Icons.home_rounded, label: 'Home'),
      _NavItem(path: '/nfc-capture', icon: Icons.nfc_rounded, label: 'Capture'),
      _NavItem(
        path: '/network-simulator',
        icon: Icons.hub_rounded,
        label: 'Network',
      ),
      _NavItem(
        path: '/specialist',
        icon: Icons.medical_services_rounded,
        label: 'Console',
      ),
      _NavItem(
        path: '/settings',
        icon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0x26FFFFFF)  // 15% white on dark
                  : const Color(0xBBFFFFFF), // 73% white on light
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x44FFFFFF),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: items.map((item) {
                final isActive = currentPath == item.path ||
                    (item.path == '/home' &&
                        (currentPath == '/' || currentPath.isEmpty));
                return Expanded(
                  child: _NavBarItem(
                    item: item,
                    isActive: isActive,
                    isDark: isDark,
                    activeColor: colorScheme.primary,
                    inactiveColor: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.65),
                    onTap: () => context.go(item.path),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.isDark,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final bool isDark;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: widget.isActive
              ? BoxDecoration(
                  color: widget.activeColor.withValues(alpha: widget.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.activeColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                )
              : const BoxDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  widget.item.icon,
                  key: ValueKey(widget.isActive),
                  color: widget.isActive
                      ? widget.activeColor
                      : widget.inactiveColor,
                  size: widget.isActive ? 24 : 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: widget.isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isActive
                      ? widget.activeColor
                      : widget.inactiveColor,
                  letterSpacing: widget.isActive ? 0.3 : 0,
                ),
                child: Text(widget.item.label),
              ),
              // Active indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: widget.isActive ? 16 : 0,
                decoration: BoxDecoration(
                  color: widget.activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.path, required this.icon, required this.label});

  final String path;
  final IconData icon;
  final String label;
}
