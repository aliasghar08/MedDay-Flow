import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medday_flow/providers/auth_provider.dart' as app_auth;
import 'package:medday_flow/providers/medication_provider.dart';
import 'package:medday_flow/screens/add_medication_page.dart';
import 'package:medday_flow/services/medication_analytics_service.dart';
import 'package:medday_flow/services/medication_pdf_report_service.dart';
import 'package:medday_flow/widgets/charts/custom_charts.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';
import 'package:medday_flow/widgets/medication_pill_graphic.dart';
import 'package:medday_flow/widgets/ad_banner_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medday_flow/services/custom_state_management.dart';

class MedicationDetailPage extends StatefulWidget {
  final Medication medication;
  final int initialTabIndex;

  const MedicationDetailPage({
    super.key,
    required this.medication,
    this.initialTabIndex = 0,
  });

  @override
  State<MedicationDetailPage> createState() => _MedicationDetailPageState();
}

class _MedicationDetailPageState extends State<MedicationDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MedicationIntake> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadIntakeHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blueAccent;
    }
  }

  Future<void> _loadIntakeHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final authProvider = context.read<app_auth.AuthProvider>();
    final medProvider = context.read<MedicationProvider>();
    final userId = authProvider.user?.uid;

    if (userId == null) {
      setState(() {
        _isLoadingHistory = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(widget.medication.medicationId)
          .collection('intakes')
          .orderBy('scheduledTime', descending: true)
          .limit(500)
          .get();

      final List<MedicationIntake> list = [];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final scheduleId = data['scheduleId'];
          MedicationSchedule? sched;
          try {
            sched = medProvider.schedules
                .firstWhere((s) => s.scheduleId == scheduleId);
          } catch (_) {
            sched = null;
          }
          list.add(MedicationIntake.fromMap(data, doc.id, sched));
        } catch (e) {
          debugPrint('Error parsing history intake: $e');
        }
      }

      setState(() {
        _history = list;
      });
    } catch (e) {
      debugPrint('Error loading intake history: $e');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final medProvider = context.watch<MedicationProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final medColor = _parseColor(widget.medication.color);

    // Find schedule for this medication
    final schedule = medProvider.schedules.cast<MedicationSchedule?>().firstWhere(
          (s) => s?.medication.medicationId == widget.medication.medicationId,
          orElse: () => null,
        );

    final takenCount = _history.where((i) => i.status == IntakeStatus.taken).length;
    final skippedCount = _history.where((i) => i.status == IntakeStatus.skipped).length;
    final totalLogged = _history.length;
    final adherenceRate = totalLogged > 0 ? (takenCount / totalLogged) : 1.0;

    final analytics = MedicationAnalyticsService.computeAnalytics(
      medication: widget.medication,
      history: _history,
      schedule: schedule,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(widget.medication.name),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.blueAccent),
            tooltip: 'Export Medical PDF Report',
            onPressed: () => _exportPdf(schedule),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Medication',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddMedicationPage(
                    existingMedication: widget.medication,
                    existingSchedule: schedule,
                  ),
                ),
              );
              _loadIntakeHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(medProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: medColor,
          labelColor: medColor,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined, size: 20)),
            Tab(text: 'Analytics', icon: Icon(Icons.insights_rounded, size: 20)),
            Tab(text: 'History', icon: Icon(Icons.history_rounded, size: 20)),
            Tab(text: 'Schedule', icon: Icon(Icons.alarm_on_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Overview
          _buildOverviewTab(medColor, isDark, adherenceRate, takenCount, skippedCount, totalLogged, schedule, analytics),
          // Tab 2: Analytics
          _buildAnalyticsTab(analytics, isDark, medColor, schedule),
          // Tab 3: History
          _buildHistoryTab(isDark, medProvider, schedule),
          // Tab 4: Schedule Details
          _buildScheduleTab(schedule, isDark),
        ],
      ),
      bottomNavigationBar: const AdBannerWidget(),
    );
  }

  Future<void> _exportPdf(MedicationSchedule? schedule) async {
    final authProvider = context.read<app_auth.AuthProvider>();
    await MedicationPdfReportService.exportPdfReport(
      context: context,
      medication: widget.medication,
      history: _history,
      schedule: schedule,
      userName: authProvider.user?.displayName,
      userEmail: authProvider.user?.email,
    );
  }

  // ---------------------------------------------
  // TAB 1: OVERVIEW
  // ---------------------------------------------
  Widget _buildOverviewTab(
    Color medColor,
    bool isDark,
    double adherenceRate,
    int takenCount,
    int skippedCount,
    int totalLogged,
    MedicationSchedule? schedule,
    MedicationAnalyticsData analytics,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Medication Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              MedicationPillGraphic(
                shape: MedicationShape.fromString(widget.medication.shape),
                primaryColor: medColor,
                secondaryColor: widget.medication.secondaryColor != null
                    ? _parseColor(widget.medication.secondaryColor!)
                    : null,
                size: 64,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.medication.medicationClass != null &&
                        widget.medication.medicationClass!.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.purple.shade900 : Colors.purple.shade50),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          widget.medication.medicationClass!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.purple.shade200 : Colors.purple.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.medication.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.medication.formula != null &&
                        widget.medication.formula!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.biotech_outlined,
                            size: 15,
                            color: isDark ? Colors.cyan.shade200 : const Color(0xFF0E7490),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.medication.formula!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.cyan.shade200 : const Color(0xFF0E7490),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${widget.medication.dosage} ${widget.medication.unit.name}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.medication.description != null &&
                        widget.medication.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.medication.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick In-Depth Analytics & PDF Export Shortcut Card
        Container(
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
                blurRadius: 14,
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
                  const Row(
                    children: [
                      Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Medication Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(analytics.adherenceRate * 100).toInt()}% Adherence',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickMetricChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${analytics.currentStreakDays}d Streak',
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickMetricChip(
                      icon: Icons.timer_outlined,
                      label: '${(analytics.onTimePercentage * 100).toInt()}% On-Time',
                      color: Colors.lightGreenAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickMetricChip(
                      icon: Icons.medication_rounded,
                      label: '${analytics.totalScheduled} Total',
                      color: Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1D4ED8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.insights_rounded, size: 18),
                      label: const Text('View Charts', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _tabController.animateTo(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _exportPdf(schedule),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Pharmaceutical Formulation & Specifications Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.science_rounded, size: 20, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Formulation & Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.medication.formula != null && widget.medication.formula!.trim().isNotEmpty) ...[
                _buildStatRow('Active Formula', widget.medication.formula!),
                const Divider(height: 20),
              ],
              if (widget.medication.medicationClass != null && widget.medication.medicationClass!.trim().isNotEmpty) ...[
                _buildStatRow('Therapeutic Class', widget.medication.medicationClass!),
                const Divider(height: 20),
              ],
              _buildStatRow(
                'Dosage Strength',
                '${widget.medication.dosage} ${widget.medication.unit.name}',
              ),
              const Divider(height: 20),
              _buildStatRow(
                'Tablet Form Factor',
                widget.medication.shape.toUpperCase(),
              ),
              if (widget.medication.secondaryColor != null) ...[
                const Divider(height: 20),
                _buildStatRow('Appearance', 'Dual-Tone / Split Coated'),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Adherence Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adherence Summary',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: totalLogged == 0 ? 1.0 : adherenceRate,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(medColor),
                        ),
                        Center(
                          child: Text(
                            totalLogged == 0
                                ? '100%'
                                : '${(adherenceRate * 100).toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatRow('Total Logged', '$totalLogged doses'),
                        const SizedBox(height: 6),
                        _buildStatRow('Taken On-Time', '$takenCount', Colors.green),
                        const SizedBox(height: 6),
                        _buildStatRow('Skipped', '$skippedCount', Colors.orange),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick Instructions & Notes Card
        if (schedule?.instructions != null && schedule!.instructions!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: isDark ? 0.1 : 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    schedule.instructions!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------
  // TAB 2: IN-DEPTH ANALYTICS & CHARTS
  // ---------------------------------------------
  Widget _buildAnalyticsTab(
    MedicationAnalyticsData analytics,
    bool isDark,
    Color medColor,
    MedicationSchedule? schedule,
  ) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights_rounded, size: 54, color: Colors.blueAccent),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Intake Analytics Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Mark your doses as taken on the daily schedule to unlock in-depth adherence charts, punctuality scores, streaks, and PDF medical reports.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Export Baseline Prescription PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _exportPdf(schedule),
              ),
            ],
          ),
        ),
      );
    }

    final totalDoses = analytics.totalScheduled;
    final takenDoses = analytics.takenCount;
    final skippedDoses = analytics.skippedCount;
    final missedDoses = analytics.missedCount;
    final pendingDoses = analytics.pendingCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Export PDF Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Medical Report (PDF)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Complete history with analytics charts at the top',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _exportPdf(schedule),
                child: const Text('Export', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. 4-Box Primary Metric KPI Scorecards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Adherence',
                value: '${(analytics.adherenceRate * 100).toInt()}%',
                subtitle: '$takenDoses of $totalDoses taken',
                icon: Icons.check_circle_outline_rounded,
                color: analytics.adherenceRate >= 0.8
                    ? const Color(0xFF10B981)
                    : (analytics.adherenceRate >= 0.6 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'On-Time Rate',
                value: '${(analytics.onTimePercentage * 100).toInt()}%',
                subtitle: '${analytics.onTimeCount} on-time doses',
                icon: Icons.timer_outlined,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Active Streak',
                value: '${analytics.currentStreakDays}d',
                subtitle: 'Best: ${analytics.bestStreakDays}d streak',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFF97316),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: 'Total Volume',
                value: analytics.totalDosageConsumed.toStringAsFixed(analytics.totalDosageConsumed % 1 == 0 ? 0 : 1),
                subtitle: '${widget.medication.unit.name} consumed',
                icon: Icons.medication_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 3. Intake Status Breakdown Donut Chart (CustomPieChart)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Intake Status Breakdown',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$totalDoses Total Events',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 180,
                child: CustomPieChart(
                  centerSpaceRadius: 42,
                  sectionsSpace: 3,
                  centerWidget: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$totalDoses',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'doses',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  sections: [
                    if (takenDoses > 0)
                      CustomPieSliceData(
                        value: takenDoses.toDouble(),
                        color: const Color(0xFF10B981),
                        title: '$takenDoses',
                        radius: 36,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    if (skippedDoses > 0)
                      CustomPieSliceData(
                        value: skippedDoses.toDouble(),
                        color: const Color(0xFFF59E0B),
                        title: '$skippedDoses',
                        radius: 36,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    if (missedDoses > 0)
                      CustomPieSliceData(
                        value: missedDoses.toDouble(),
                        color: const Color(0xFFEF4444),
                        title: '$missedDoses',
                        radius: 36,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    if (pendingDoses > 0)
                      CustomPieSliceData(
                        value: pendingDoses.toDouble(),
                        color: const Color(0xFF3B82F6),
                        title: '$pendingDoses',
                        radius: 36,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Status Legends
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildStatusLegendChip(
                    label: 'Taken ($takenDoses)',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  _buildStatusLegendChip(
                    label: 'Skipped ($skippedDoses)',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  _buildStatusLegendChip(
                    label: 'Missed ($missedDoses)',
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                  ),
                  if (pendingDoses > 0)
                    _buildStatusLegendChip(
                      label: 'Pending ($pendingDoses)',
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 4. 14-Day Adherence Trend Bar Chart (CustomBarChart)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '14-Day Adherence Trend',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Daily Compliance',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: CustomBarChart(
                  maxY: 100,
                  minY: 0,
                  showGrid: true,
                  gridColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  bottomTitleBuilder: (index, label) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    );
                  },
                  barGroups: List.generate(analytics.dailyTrendLast14Days.length, (i) {
                    final pt = analytics.dailyTrendLast14Days[i];
                    final pct = pt.total > 0 ? (pt.taken / pt.total) * 100 : 0.0;
                    Color barColor = const Color(0xFF10B981);
                    if (pt.total == 0) {
                      barColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
                    } else if (pct < 50) {
                      barColor = const Color(0xFFEF4444);
                    } else if (pct < 100) {
                      barColor = const Color(0xFFF59E0B);
                    }

                    return CustomBarGroupData(
                      x: i,
                      label: DateFormat('d').format(pt.date),
                      barRods: [
                        CustomBarRodData(
                          toY: pt.total == 0 ? 5.0 : pct,
                          color: barColor,
                          width: 12,
                          borderRadius: BorderRadius.circular(4),
                          tooltip: '${DateFormat('MMM d').format(pt.date)}: ${pt.taken}/${pt.total} taken (${pct.toInt()}%)',
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 5. Timing Punctuality & Variance Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dosing Punctuality & Timing',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Avg Delay: ${analytics.averageDelayMinutes.toInt()} min',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildPunctualityProgressBar(
                label: 'On-Time (within 30 mins)',
                count: analytics.onTimeCount,
                total: takenDoses,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPunctualityProgressBar(
                label: 'Slightly Delayed (30-90 mins)',
                count: analytics.delayedCount,
                total: takenDoses,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPunctualityProgressBar(
                label: 'Significantly Late (>90 mins)',
                count: analytics.significantlyDelayedCount,
                total: takenDoses,
                color: const Color(0xFFEF4444),
                isDark: isDark,
              ),
              if (analytics.earlyCount > 0) ...[
                const SizedBox(height: 10),
                _buildPunctualityProgressBar(
                  label: 'Taken Early (>15 mins prior)',
                  count: analytics.earlyCount,
                  total: takenDoses,
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 6. Day of the Week Distribution Grid
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Day-of-Week Adherence Consistency',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Comparison of adherence rates across days of the week',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: analytics.dayOfWeekStats.map((d) {
                  final pct = (d.adherenceRate * 100).toInt();
                  Color barColor = const Color(0xFF10B981);
                  if (d.totalScheduled == 0) {
                    barColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
                  } else if (pct < 60) {
                    barColor = const Color(0xFFEF4444);
                  } else if (pct < 85) {
                    barColor = const Color(0xFFF59E0B);
                  }

                  return Column(
                    children: [
                      Text(
                        d.totalScheduled > 0 ? '$pct%' : '-',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: barColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 22,
                        height: 50,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FractionallySizedBox(
                          heightFactor: d.totalScheduled == 0 ? 0.05 : (d.adherenceRate > 0 ? d.adherenceRate : 0.05),
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.dayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 7. Circadian / Time of Day Windows
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Circadian Routine Windows',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Intake performance partitioned by circadian time-of-day slots',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 14),
              ...analytics.timeOfDayStats.map((slot) {
                final pct = slot.totalScheduled > 0 ? (slot.takenCount / slot.totalScheduled) : 0.0;
                IconData slotIcon = Icons.wb_sunny_outlined;
                Color slotColor = Colors.amber;
                if (slot.title == 'Afternoon') {
                  slotIcon = Icons.wb_cloudy_outlined;
                  slotColor = Colors.orange;
                } else if (slot.title == 'Evening') {
                  slotIcon = Icons.nights_stay_outlined;
                  slotColor = Colors.indigoAccent;
                } else if (slot.title == 'Night') {
                  slotIcon = Icons.bedtime_outlined;
                  slotColor = Colors.purpleAccent;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: slotColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(slotIcon, color: slotColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              slot.timeRange,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        slot.totalScheduled > 0
                            ? '${slot.takenCount}/${slot.totalScheduled} (${(pct * 100).toInt()}%)'
                            : 'No scheduled doses',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: slot.totalScheduled > 0
                              ? (pct >= 0.8 ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 8. Automated Clinical Observations & Insights
        if (analytics.clinicalInsights.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.teal.shade800 : Colors.teal.shade200,
                width: 1,
              ),
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Clinical Insights & Observations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...analytics.clinicalInsights.map((ins) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Expanded(
                        child: Text(
                          ins,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
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

  Widget _buildStatusLegendChip({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildPunctualityProgressBar({
    required String label,
    required int count,
    required int total,
    required Color color,
    required bool isDark,
  }) {
    final pct = total > 0 ? (count / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$count doses (${(pct * 100).toInt()}%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------
  // TAB 3: HISTORY
  // ---------------------------------------------
  Widget _buildHistoryTab(bool isDark, MedicationProvider medProvider, MedicationSchedule? schedule) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Intake Logs Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mark your medication as taken on the daily schedule.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Top action bar in history tab
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_history.length} Recorded Intakes',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _exportPdf(schedule),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final intake = _history[index];
              final isTaken = intake.status == IntakeStatus.taken;
              final isSkipped = intake.status == IntakeStatus.skipped;

              Color badgeBg = Colors.grey.shade200;
              Color badgeColor = Colors.grey.shade800;
              String statusLabel = 'Pending';

              if (isTaken) {
                badgeBg = Colors.green.shade50;
                badgeColor = Colors.green.shade700;
                statusLabel = 'Taken';
              } else if (isSkipped) {
                badgeBg = Colors.orange.shade50;
                badgeColor = Colors.orange.shade800;
                statusLabel = 'Skipped';
              } else if (intake.status == IntakeStatus.missed) {
                badgeBg = Colors.red.shade50;
                badgeColor = Colors.red.shade700;
                statusLabel = 'Missed';
              }

              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () => _showModifyIntakeBottomSheet(context, intake),
                  leading: Icon(
                    isTaken
                        ? Icons.check_circle_rounded
                        : (isSkipped ? Icons.remove_circle_outline : Icons.schedule_rounded),
                    color: badgeColor,
                  ),
                  title: Text(
                    DateFormat('EEEE, MMM d, yyyy').format(intake.logicalDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Scheduled: ${DateFormat('h:mm a').format(intake.scheduledTime)}${intake.actualTime != null ? ' • Logged: ${DateFormat('h:mm a').format(intake.actualTime!)}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showModifyIntakeBottomSheet(BuildContext context, MedicationIntake intake) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Modify Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (intake.status != IntakeStatus.taken)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Mark as Taken'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(intake.scheduledTime),
                      helpText: 'Select time taken',
                    );
                    
                    if (pickedTime != null) {
                      final logical = intake.logicalDate;
                      final targetDate = (pickedTime.hour < MedicationIntake.defaultCircadianCutoffHour)
                          ? logical.add(const Duration(days: 1))
                          : logical;
                          
                      final actualTime = DateTime(
                        targetDate.year,
                        targetDate.month,
                        targetDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      if (context.mounted) {
                        try {
                          await context.read<MedicationProvider>().markIntake(
                            intake: intake,
                            status: IntakeStatus.taken,
                            actualTime: actualTime,
                          );
                          _loadIntakeHistory();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                ),
              if (intake.status != IntakeStatus.skipped)
                ListTile(
                  leading: const Icon(Icons.remove_circle, color: Colors.orange),
                  title: const Text('Mark as Skipped'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await context.read<MedicationProvider>().markIntake(intake: intake, status: IntakeStatus.skipped);
                      _loadIntakeHistory();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              if (intake.status != IntakeStatus.missed)
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.red),
                  title: const Text('Mark as Missed'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await context.read<MedicationProvider>().markIntake(intake: intake, status: IntakeStatus.missed);
                      _loadIntakeHistory();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.pending_actions, color: Colors.grey),
                title: const Text('Reset to Pending'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await context.read<MedicationProvider>().markIntake(intake: intake, status: IntakeStatus.pending);
                    _loadIntakeHistory();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------
  // TAB 3: SCHEDULE
  // ---------------------------------------------
  Widget _buildScheduleTab(MedicationSchedule? schedule, bool isDark) {
    if (schedule == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No Active Schedule',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddMedicationPage(
                      existingMedication: widget.medication,
                    ),
                  ),
                );
              },
              child: const Text('Add Schedule'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                _buildScheduleDetailRow(
                  'Frequency',
                  schedule.frequency.name.toUpperCase(),
                ),
                const SizedBox(height: 12),
                _buildScheduleDetailRow(
                  'Doses Per Day',
                  '${schedule.timesPerDay.length} time(s)',
                ),
                const SizedBox(height: 12),
                _buildScheduleDetailRow(
                  'Times',
                  schedule.timesPerDay
                      .map((t) => DateFormat('h:mm a').format(
                            DateTime(2022, 1, 1, t.hour, t.minute),
                          ))
                      .join(', '),
                ),
                const SizedBox(height: 12),
                _buildScheduleDetailRow(
                  'Start Date',
                  DateFormat('MMM d, yyyy').format(schedule.startDate),
                ),
                if (schedule.endDate != null) ...[
                  const SizedBox(height: 12),
                  _buildScheduleDetailRow(
                    'End Date',
                    DateFormat('MMM d, yyyy').format(schedule.endDate!),
                  ),
                ],
                const SizedBox(height: 12),
                _buildScheduleDetailRow(
                  'Reminder Alert',
                  '${schedule.reminderMinutesBefore} mins before',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  void _confirmDelete(MedicationProvider medProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.medication.name}?'),
        content: const Text(
          'This will permanently delete this medication, its schedules, and all recorded intakes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close detail page
              await medProvider.deleteMedication(widget.medication.medicationId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}