import 'dart:async';
import 'package:flutter/services.dart';
import 'package:medday_flow/providers/auth_provider.dart' as app_auth;
import 'package:medday_flow/providers/medication_provider.dart';
import 'package:medday_flow/providers/task_provider.dart';
import 'package:medday_flow/screens/add_medication_page.dart';
import 'package:medday_flow/screens/add_item_page.dart';
import 'package:medday_flow/screens/medication_detail_page.dart';
import 'package:medday_flow/screens/medication_list_page.dart';
import 'package:medday_flow/utils/alarm_helper.dart';
import 'package:medday_flow/utils/catalog.dart';
import 'package:medday_flow/utils/drawer.dart';
import 'package:medday_flow/utils/item.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/widgets/ad_banner_widget.dart';
import 'package:medday_flow/widgets/medication_pill_graphic.dart';
import 'package:medday_flow/widgets/premium_animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medday_flow/services/custom_state_management.dart';
import 'dart:io' show Platform;

enum TaskFilter { all, completed, incomplete, overdue }

class MyHome extends StatefulWidget {
  final bool isInsideNavShell;
  const MyHome({super.key, this.isInsideNavShell = false});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounceTimer;
  bool _nativeAlarmInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);

    _initializeNativeAlarmHelper();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final authProvider = context.read<app_auth.AuthProvider>();
      await authProvider.refreshToken();

      if (!mounted) return;
      if (authProvider.user != null) {
        final taskProv = context.read<TaskProvider>();
        final medProv = context.read<MedicationProvider>();
        await taskProv.fetchTasks(authProvider.user!);
        if (!mounted) return;
        await medProv.loadMedications(authProvider.user!.uid);
        if (!mounted) return;
        await medProv.refreshPersonalizationInsights(taskProv.tasks);
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.read<TaskProvider>().setSearchQuery(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeNativeAlarmHelper() async {
    try {
      await NativeAlarmHelper.initialize();
      if (mounted) {
        setState(() {
          _nativeAlarmInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('NativeAlarmHelper initialization note: $e');
    }
  }

  Future<void> _navigateToAddTask() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final taskProvider = context.read<TaskProvider>();

    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskPage()),
    );
    if (added == true && authProvider.user != null) {
      await taskProvider.fetchTasks(authProvider.user!);
    }
  }

  Future<void> _navigateToAddMedication() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationPage()),
    );
  }

  void _showAddOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Quick Create',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Schedule one-time or recurring reminders'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToAddTask();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication_outlined, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Add Medication', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Log doses, frequencies and inventory'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToAddMedication();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modern Hero Progress & Summary Banner
  Widget _buildSummaryHeroCard(TaskProvider taskProvider, MedicationProvider medProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = taskProvider.totalTasksCount;
    final completed = taskProvider.completedTasksCount;
    final incomplete = taskProvider.incompleteTasksCount;
    final overdue = taskProvider.overdueTasksCount;
    final progress = taskProvider.completionRate;
    final formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final topItem = medProvider.topRankedItem;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Today's Overview",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Circular Percentage Badge
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: total == 0 ? 0.0 : progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    total == 0 ? "0%" : "${(progress * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Statistics Pills Row
          Row(
            children: [
              _buildStatChip("Done", completed, const Color(0xFF10B981), Icons.check_circle),
              const SizedBox(width: 8),
              _buildStatChip("Pending", incomplete, const Color(0xFFF59E0B), Icons.schedule),
              const SizedBox(width: 8),
              _buildStatChip("Overdue", overdue, const Color(0xFFEF4444), Icons.error_outline),
            ],
          ),
          if (topItem != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'UP NEXT',
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${topItem.title} (${topItem.subtitle}) • ${topItem.reason}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  /// Dedicated glassmorphic / elevated "Due Next" Quick-Log Card
  Widget _buildDueNextQuickLogCard(MedicationProvider medProvider) {
    if (medProvider.medications.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Priority 1: Actionable due now or overdue doses
    // Priority 2: Next scheduled upcoming intake for today
    MedicationIntake? activeIntake;
    final dueNow = medProvider.dueNowIntakes;
    if (dueNow.isNotEmpty) {
      activeIntake = dueNow.first;
    } else {
      activeIntake = medProvider.nextUpcomingIntake;
    }

    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SmoothContentSwitcher(
        child: activeIntake == null
            ? Container(
                key: const ValueKey('all_caught_up_card'),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Caught Up for Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All scheduled doses for today are logged. Great job!',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : _buildActiveDoseCard(activeIntake, isDark, cardBgColor, borderColor, now, medProvider),
      ),
    );
  }

  Widget _buildActiveDoseCard(
    MedicationIntake intake,
    bool isDark,
    Color cardBgColor,
    Color borderColor,
    DateTime now,
    MedicationProvider medProvider,
  ) {
    final med = intake.schedule.medication;
    final medColor = _parseColor(med.color);
    final secondaryColor = med.secondaryColor != null ? _parseColor(med.secondaryColor!) : null;

    final isOverdue = intake.isOverdue(now);
    final isDueNow = intake.isDueNow(now);
    final diffMinutes = intake.scheduledTime.difference(now).inMinutes;
    final timeStr = DateFormat('h:mm a').format(intake.scheduledTime);

    String statusText;
    Color statusColor;
    if (isOverdue) {
      statusText = 'Overdue • $timeStr';
      statusColor = const Color(0xFFEF4444);
    } else if (isDueNow) {
      statusText = 'Due Now • $timeStr';
      statusColor = const Color(0xFFF59E0B);
    } else if (diffMinutes > 0 && diffMinutes <= 60) {
      statusText = 'Due in ${diffMinutes}m • $timeStr';
      statusColor = const Color(0xFF2563EB);
    } else {
      statusText = 'Due at $timeStr';
      statusColor = const Color(0xFF10B981);
    }

    final dosageStr = '${med.dosage % 1 == 0 ? med.dosage.toInt() : med.dosage} ${med.unit.name}';

    return TactilePressScale(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicationDetailPage(medication: med),
          ),
        );
      },
      child: Container(
        key: ValueKey('due_next_${intake.intakeId}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOverdue ? const Color(0xFFEF4444).withValues(alpha: 0.35) : borderColor,
            width: isOverdue ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top tag: "DUE NEXT" + Time status pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DUE NEXT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // 3D Pill Graphic with Hero transition
                Hero(
                  tag: 'med_pill_${med.medicationId}',
                  child: MedicationPillGraphic(
                    shape: MedicationShape.fromString(med.shape),
                    primaryColor: medColor,
                    secondaryColor: secondaryColor,
                    size: 46,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (med.formula != null && med.formula!.trim().isNotEmpty) ...[
                            Flexible(
                              child: Text(
                                med.formula!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const Text(' • ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                          Text(
                            dosageStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Tactile One-Tap Take Button
                TactilePressScale(
                  targetScale: 0.92,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await medProvider.markIntake(
                      intake: intake,
                      status: IntakeStatus.taken,
                      actualTime: DateTime.now(),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        content: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${med.name} logged as taken',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Take',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact, dismissible smart banner suggesting adaptive schedule/cutoff changes
  Widget _buildSmartInsightBanner(MedicationProvider medProvider) {
    if (!medProvider.isPersonalizationEnabled) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shift = medProvider.activeReminderShiftSuggestion;
    final cutoff = medProvider.activeCircadianCutoffSuggestion;

    if (shift == null && cutoff == null) {
      return const SizedBox.shrink();
    }

    final isShift = shift != null;
    final title = isShift ? 'Smart Reminder Shift' : 'Circadian Schedule Calibration';
    final explanation = isShift ? shift.explanation : cutoff!.explanation;
    final icon = isShift ? Icons.alarm_on_rounded : Icons.bedtime_rounded;
    final accentColor = isShift ? const Color(0xFF6366F1) : const Color(0xFF8B5CF6);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
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
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AI Insight',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      explanation,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  if (isShift) {
                    await medProvider.dismissReminderShift(shift);
                  } else {
                    await medProvider.dismissCircadianCutoff(cutoff!);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Suggestion snoozed for 14 days'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  if (isShift) {
                    await medProvider.applyReminderShift(shift);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Shifted ${shift.medicationName} reminder to ${shift.formattedSuggestedTime}'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    await medProvider.applyCircadianCutoff(cutoff!);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated day cutoff to ${cutoff.formattedSuggestedHour}'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 14),
                label: const Text('Apply', style: TextStyle(fontSize: 12.5)),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "$count $label",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search tasks by title or details...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    context.read<TaskProvider>().clearSearch();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTabBar(TaskProvider taskProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
        unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        tabs: [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("All (${taskProvider.getTaskCount(TaskFilter.all)})"),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("Done (${taskProvider.getTaskCount(TaskFilter.completed)})"),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("Pending (${taskProvider.getTaskCount(TaskFilter.incomplete)})"),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("Overdue (${taskProvider.getTaskCount(TaskFilter.overdue)})"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TaskFilter filter, bool isSearching) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    if (isSearching) {
      title = "No tasks found";
      subtitle = "No tasks match your search query.";
      icon = Icons.search_off_rounded;
      iconColor = Colors.grey;
    } else {
      switch (filter) {
        case TaskFilter.completed:
          title = "No completed tasks yet";
          subtitle = "Check off tasks as you finish them!";
          icon = Icons.check_circle_outline_rounded;
          iconColor = const Color(0xFF10B981);
          break;
        case TaskFilter.incomplete:
          title = "All caught up!";
          subtitle = "You have no pending tasks right now.";
          icon = Icons.done_all_rounded;
          iconColor = const Color(0xFF2563EB);
          break;
        case TaskFilter.overdue:
          title = "Zero overdue tasks!";
          subtitle = "Awesome job staying on schedule.";
          icon = Icons.celebration_outlined;
          iconColor = const Color(0xFF10B981);
          break;
        case TaskFilter.all:
          title = "No tasks created yet";
          subtitle = "Tap below to add your first task.";
          icon = Icons.add_task_rounded;
          iconColor = const Color(0xFF2563EB);
          break;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!isSearching && filter == TaskFilter.all)
              FilledButton.icon(
                onPressed: _navigateToAddTask,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Create Task"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedTaskList(TaskFilter filter) {
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.watch<app_auth.AuthProvider>();
    final filtered = taskProvider.getFilteredTasks(filter);
    final isSearching = taskProvider.searchQuery.isNotEmpty;

    if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filtered.isEmpty) {
      return _buildEmptyState(filter, isSearching);
    }

    // Grouping tasks efficiently
    final List<Task> oneTimeTasks = [];
    final List<Task> dailyTasks = [];
    final List<Task> weeklyTasks = [];
    final List<Task> monthlyTasks = [];

    for (var task in filtered) {
      final type = task.taskType.toLowerCase();
      if (type == 'dailytask') {
        dailyTasks.add(task);
      } else if (type == 'weeklytask') {
        weeklyTasks.add(task);
      } else if (type == 'monthlytask') {
        monthlyTasks.add(task);
      } else {
        oneTimeTasks.add(task);
      }
    }

    final groups = [
      if (dailyTasks.isNotEmpty) ('Daily Tasks', dailyTasks, const Color(0xFF3B82F6)),
      if (oneTimeTasks.isNotEmpty) ('One-Time Tasks', oneTimeTasks, const Color(0xFF64748B)),
      if (weeklyTasks.isNotEmpty) ('Weekly Tasks', weeklyTasks, const Color(0xFF10B981)),
      if (monthlyTasks.isNotEmpty) ('Monthly Tasks', monthlyTasks, const Color(0xFF8B5CF6)),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        if (authProvider.user != null) {
          await taskProvider.fetchTasks(authProvider.user!, showLoading: false);
          if (!mounted) return;
          final medProvider = context.read<MedicationProvider>();
          await medProvider.refreshPersonalizationInsights(taskProvider.tasks);
        }
      },
      child: ListView.builder(
        key: PageStorageKey<String>('taskList_${filter.name}'),
        padding: const EdgeInsets.only(bottom: 96, top: 4),
        itemCount: groups.fold<int>(0, (sum, g) => sum + 1 + g.$2.length),
        itemBuilder: (context, index) {
          int count = 0;
          for (var group in groups) {
            final title = group.$1;
            final taskList = group.$2;
            final color = group.$3;

            // Header position
            if (index == count) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${taskList.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            count++;
            // Items in group
            if (index < count + taskList.length) {
              final task = taskList[index - count];
              return StaggeredEntrance(
                index: index,
                child: ItemWidget(
                  key: ValueKey('task_${task.docId ?? task.title}'),
                  item: task,
                  searchQuery: taskProvider.searchQuery,
                  onEditDone: () async {
                    if (authProvider.user != null) {
                      await taskProvider.fetchTasks(authProvider.user!, showLoading: false);
                    }
                  },
                ),
              );
            }

            count += taskList.length;
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final medProvider = context.watch<MedicationProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Medday Flow"),
        actions: [
          IconButton(
            icon: const Icon(Icons.medication_outlined),
            tooltip: 'Medications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicationListPage()),
              );
            },
          ),
          if (Platform.isAndroid && _nativeAlarmInitialized)
            IconButton(
              icon: const Icon(Icons.alarm_on_outlined),
              tooltip: 'Background Setup Guide',
              onPressed: () => NativeAlarmHelper.showOemOptimizationGuide(context),
            ),
        ],
      ),
      drawer: const MyDrawer(),
      body: (authProvider.isLoading ||
              ((user != null) &&
                  (taskProvider.isInitialLoading || medProvider.isInitialLoading)))
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Loading your day...",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            )
          : user == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 54, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("Please log in to manage your daily tasks"),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text("Go to Login"),
                      ),
                    ],
                  ),
                )
              : NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: StaggeredColumn(
                        children: [
                          _buildSummaryHeroCard(taskProvider, medProvider),
                          _buildDueNextQuickLogCard(medProvider),
                          _buildSmartInsightBanner(medProvider),
                          _buildSearchBar(),
                          _buildTabBar(taskProvider),
                        ],
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGroupedTaskList(TaskFilter.all),
                      _buildGroupedTaskList(TaskFilter.completed),
                      _buildGroupedTaskList(TaskFilter.incomplete),
                      _buildGroupedTaskList(TaskFilter.overdue),
                    ],
                  ),
                ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddOptions,
              icon: const Icon(Icons.add),
              label: const Text("Add"),
            ),
      bottomNavigationBar: widget.isInsideNavShell ? null : const AdBannerWidget(),
    );
  }
}