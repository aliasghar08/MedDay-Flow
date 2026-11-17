import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medday_flow/screens/home.dart';
import 'package:medday_flow/screens/medication_list_page.dart';
import 'package:medday_flow/screens/settings.dart';
import 'package:medday_flow/screens/unified_insights_view.dart';
import 'package:medday_flow/widgets/ad_banner_widget.dart';
import 'package:medday_flow/widgets/premium_animations.dart';

/// Persistent 4-Tab Navigation Shell for MedDay Flow.
/// Houses Home, Medications, Insights, and Settings with instant IndexedStack
/// state preservation, smooth transitions, tactile feedback, and unified ad banners.
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  final List<Widget>? testTabViews;

  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
    this.testTabViews,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _tabFadeController;
  late final Animation<double> _tabFadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _tabFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _tabFadeAnimation = CurvedAnimation(
      parent: _tabFadeController,
      curve: Curves.easeOutCubic,
    );

    _tabFadeController.forward();
  }

  @override
  void dispose() {
    _tabFadeController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.selectionClick();
    _tabFadeController.reset();
    setState(() {
      _currentIndex = index;
    });
    _tabFadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: FadeTransition(
        opacity: _tabFadeAnimation,
        child: IndexedStack(
          index: _currentIndex,
          children: widget.testTabViews ?? const [
            MyHome(isInsideNavShell: true),
            MedicationListPage(isInsideNavShell: true),
            UnifiedInsightsView(),
            SettingsPage(isInsideNavShell: true),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCustomBottomNavBar(theme, isDark),
            const AdBannerWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBottomNavBar(ThemeData theme, bool isDark) {
    final navBgColor = isDark ? const Color(0xFF16181D) : Colors.white;
    final topBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: navBgColor,
        border: Border(
          top: BorderSide(color: topBorderColor, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            index: 0,
            label: 'Home',
            outlinedIcon: Icons.home_outlined,
            filledIcon: Icons.home_rounded,
            theme: theme,
            isDark: isDark,
          ),
          _buildNavItem(
            index: 1,
            label: 'Medications',
            outlinedIcon: Icons.medication_outlined,
            filledIcon: Icons.medication_rounded,
            theme: theme,
            isDark: isDark,
          ),
          _buildNavItem(
            index: 2,
            label: 'Insights',
            outlinedIcon: Icons.insights_outlined,
            filledIcon: Icons.insights_rounded,
            theme: theme,
            isDark: isDark,
          ),
          _buildNavItem(
            index: 3,
            label: 'Settings',
            outlinedIcon: Icons.settings_outlined,
            filledIcon: Icons.settings_rounded,
            theme: theme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData outlinedIcon,
    required IconData filledIcon,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = isDark
        ? Colors.grey.shade400
        : const Color(0xFF64748B);

    return Expanded(
      child: TactilePressScale(
        onTap: () => _onTabSelected(index),
        targetScale: 0.94,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isSelected ? filledIcon : outlinedIcon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
