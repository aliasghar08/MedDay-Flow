import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medday_flow/providers/medication_provider.dart';
import 'package:medday_flow/providers/task_provider.dart';
import 'package:medday_flow/screens/sync_integrations_page.dart';
import 'package:medday_flow/services/custom_state_management.dart';
import 'package:medday_flow/utils/performance_page/daily_tasks.dart';
import 'package:medday_flow/utils/performance_page/total_tasks.dart';
import 'package:medday_flow/widgets/premium_animations.dart';

/// Unified Performance & Adherence Insights screen.
/// Combines medication adherence analytics and task productivity into a cohesive dashboard.
class UnifiedInsightsView extends StatefulWidget {
  const UnifiedInsightsView({super.key});

  @override
  State<UnifiedInsightsView> createState() => _UnifiedInsightsViewState();
}

class _UnifiedInsightsViewState extends State<UnifiedInsightsView>
    with SingleTickerProviderStateMixin {
  int _selectedSegment = 0; // 0: Medications, 1: Tasks

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final medProvider = context.watch<MedicationProvider>();
    final taskProvider = context.watch<TaskProvider>();

    final backgroundColor = isDark ? const Color(0xFF101216) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1A1D24) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF16181D) : Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Insights & Trends',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync & Integrations',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncIntegrationsPage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Segmented Tab Selector
          _buildSegmentedControl(isDark),

          const SizedBox(height: 16),

          // Animated Content Switcher between Medication and Task Insights
          SmoothContentSwitcher(
            child: _selectedSegment == 0
                ? _buildMedicationInsightsTab(medProvider, cardColor, borderColor, isDark)
                : _buildTaskInsightsTab(taskProvider, cardColor, borderColor, isDark),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(bool isDark) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveBg = isDark ? const Color(0xFF1F232B) : const Color(0xFFEEF2F6);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: inactiveBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TactilePressScale(
              onTap: () {
                if (_selectedSegment != 0) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSegment = 0);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSegment == 0
                      ? (isDark ? const Color(0xFF2B303C) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedSegment == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_rounded,
                      size: 18,
                      color: _selectedSegment == 0 ? activeColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Medications',
                      style: TextStyle(
                        fontWeight: _selectedSegment == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedSegment == 0
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: TactilePressScale(
              onTap: () {
                if (_selectedSegment != 1) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSegment = 1);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedSegment == 1
                      ? (isDark ? const Color(0xFF2B303C) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedSegment == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 18,
                      color: _selectedSegment == 1 ? activeColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tasks & Habits',
                      style: TextStyle(
                        fontWeight: _selectedSegment == 1 ? FontWeight.bold : FontWeight.w600,
                        color: _selectedSegment == 1
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationInsightsTab(
    MedicationProvider medProvider,
    Color cardColor,
    Color borderColor,
    bool isDark,
  ) {
    final profile = medProvider.notificationProfileConfig;
    final adherencePercent = (profile.adherenceRate * 100).round();
    final todayAdherencePercent = (medProvider.adherencePercentage * 100).round();

    return StaggeredColumn(
      key: const ValueKey('medication_insights'),
      children: [
        // 1. Rolling 7-Day Adherence Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '7-Day Adherence Score',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: profile.profile.name == 'calm'
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${profile.profile.name[0].toUpperCase()}${profile.profile.name.substring(1)} Mode',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: profile.profile.name == 'calm'
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$adherencePercent%',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '(${profile.takenDoses} of ${profile.totalScheduledDoses} logged)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: profile.adherenceRate.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    adherencePercent >= 85
                        ? const Color(0xFF10B981)
                        : (adherencePercent >= 70 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Today's Breakdown Metrics
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: "Today's Adherence",
                value: '$todayAdherencePercent%',
                subtitle: '${medProvider.takenIntakesCount} / ${medProvider.totalIntakesCount} doses',
                icon: Icons.calendar_today_rounded,
                color: const Color(0xFF2563EB),
                cardColor: cardColor,
                borderColor: borderColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Pending / Due',
                value: '${medProvider.pendingIntakesCount}',
                subtitle: medProvider.missedIntakesCount > 0
                    ? '${medProvider.missedIntakesCount} missed'
                    : 'On track today',
                icon: Icons.schedule_rounded,
                color: medProvider.missedIntakesCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                cardColor: cardColor,
                borderColor: borderColor,
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Drop-off Window Insights
        if (profile.dropOffTimeWindow != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attention Window Detected',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Most missed doses occur in the ${profile.dropOffTimeWindow} window. Supportive reminder check-ins are active.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 4. Quick Action Card
        TactilePressScale(
          onTap: () {
            // Navigate to Sync & Integrations
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SyncIntegrationsPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF8B5CF6), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apple Health & Google Calendar Sync',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Keep health records and calendar reminders synced',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskInsightsTab(
    TaskProvider taskProvider,
    Color cardColor,
    Color borderColor,
    bool isDark,
  ) {
    final completionPercent = (taskProvider.completionRate * 100).round();

    return StaggeredColumn(
      key: const ValueKey('task_insights'),
      children: [
        // 1. Overall Completion KPI Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Overall Task Completion Rate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$completionPercent%',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '(${taskProvider.completedTasksCount} of ${taskProvider.totalTasksCount} finished)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: taskProvider.completionRate,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Metrics Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Pending Tasks',
                value: '${taskProvider.incompleteTasksCount}',
                subtitle: 'Active to-dos',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFF59E0B),
                cardColor: cardColor,
                borderColor: borderColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Overdue Tasks',
                value: '${taskProvider.overdueTasksCount}',
                subtitle: taskProvider.overdueTasksCount == 0 ? 'Zero backlogs!' : 'Needs review',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
                cardColor: cardColor,
                borderColor: borderColor,
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Navigation to Detailed Historical Reports
        TactilePressScale(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyTasksStats()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Habits & Streaks Report',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View daily habit streaks and weekly breakdown charts',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        TactilePressScale(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TotalTasks()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All-Time Task Productivity',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Lifetime completions, monthly volume, and trends',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
