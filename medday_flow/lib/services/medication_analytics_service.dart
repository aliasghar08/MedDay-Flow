import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';

/// Single day intake point for trend graphs
class DailyAdherencePoint {
  final DateTime date;
  final int total;
  final int taken;
  final int missed;
  final int skipped;

  const DailyAdherencePoint({
    required this.date,
    required this.total,
    required this.taken,
    required this.missed,
    required this.skipped,
  });

  double get adherenceRate => total > 0 ? (taken / total) : 0.0;
}

/// Statistics for a specific day of the week (0 = Monday, 6 = Sunday)
class DayOfWeekStats {
  final int dayIndex; // 0..6
  final String dayName;
  final int totalScheduled;
  final int takenCount;

  const DayOfWeekStats({
    required this.dayIndex,
    required this.dayName,
    required this.totalScheduled,
    required this.takenCount,
  });

  double get adherenceRate => totalScheduled > 0 ? (takenCount / totalScheduled) : 0.0;
}

/// Statistics for circadian time-of-day windows
class TimeOfDayStats {
  final String title;
  final String timeRange;
  final int totalScheduled;
  final int takenCount;

  const TimeOfDayStats({
    required this.title,
    required this.timeRange,
    required this.totalScheduled,
    required this.takenCount,
  });

  double get adherenceRate => totalScheduled > 0 ? (takenCount / totalScheduled) : 0.0;
}

/// Consolidated analytics model for a medication
class MedicationAnalyticsData {
  final Medication medication;
  final MedicationSchedule? schedule;
  final int totalScheduled;
  final int takenCount;
  final int skippedCount;
  final int missedCount;
  final int pendingCount;
  final double adherenceRate; // 0.0 .. 1.0
  final double complianceRate; // taken / (taken + missed + skipped)
  final int currentStreakDays;
  final int bestStreakDays;
  final double totalDosageConsumed;
  final double averageDelayMinutes;
  final int onTimeCount;
  final int delayedCount;
  final int significantlyDelayedCount;
  final int earlyCount;
  final double onTimePercentage;
  final List<DayOfWeekStats> dayOfWeekStats;
  final List<TimeOfDayStats> timeOfDayStats;
  final List<DailyAdherencePoint> dailyTrendLast14Days;
  final List<DailyAdherencePoint> dailyTrendLast30Days;
  final List<String> clinicalInsights;

  const MedicationAnalyticsData({
    required this.medication,
    required this.schedule,
    required this.totalScheduled,
    required this.takenCount,
    required this.skippedCount,
    required this.missedCount,
    required this.pendingCount,
    required this.adherenceRate,
    required this.complianceRate,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.totalDosageConsumed,
    required this.averageDelayMinutes,
    required this.onTimeCount,
    required this.delayedCount,
    required this.significantlyDelayedCount,
    required this.earlyCount,
    required this.onTimePercentage,
    required this.dayOfWeekStats,
    required this.timeOfDayStats,
    required this.dailyTrendLast14Days,
    required this.dailyTrendLast30Days,
    required this.clinicalInsights,
  });
}

class MedicationAnalyticsService {
  /// Computes all analytical metrics from raw intakes and medication schedules
  static MedicationAnalyticsData computeAnalytics({
    required Medication medication,
    required List<MedicationIntake> history,
    MedicationSchedule? schedule,
  }) {
    final total = history.length;
    final taken = history.where((i) => i.status == IntakeStatus.taken).toList();
    final skipped = history.where((i) => i.status == IntakeStatus.skipped).toList();
    final missed = history.where((i) => i.status == IntakeStatus.missed).toList();
    final pending = history.where((i) => i.status == IntakeStatus.pending).toList();

    final adherence = total > 0 ? (taken.length / total) : 1.0;
    final decisiveCount = taken.length + skipped.length + missed.length;
    final compliance = decisiveCount > 0 ? (taken.length / decisiveCount) : 1.0;

    // 1. Punctuality and Timing Variance
    int onTime = 0;
    int delayed = 0;
    int significantlyDelayed = 0;
    int early = 0;
    double totalDelayMinutes = 0.0;
    int delaysRecorded = 0;

    for (final intake in taken) {
      if (intake.actualTime != null) {
        final diffMinutes = intake.actualTime!.difference(intake.scheduledTime).inMinutes;
        totalDelayMinutes += diffMinutes.abs();
        delaysRecorded++;

        if (diffMinutes < -15) {
          early++;
        } else if (diffMinutes <= 30) {
          onTime++;
        } else if (diffMinutes <= 90) {
          delayed++;
        } else {
          significantlyDelayed++;
        }
      } else {
        // Logged taken without explicit actual time treated as on-time
        onTime++;
      }
    }

    final avgDelay = delaysRecorded > 0 ? (totalDelayMinutes / delaysRecorded) : 0.0;
    final onTimePct = taken.isNotEmpty ? (onTime / taken.length) : 1.0;

    // 2. Streaks Calculation
    // Group intakes by logical date
    final Map<DateTime, List<MedicationIntake>> byDate = {};
    for (final intake in history) {
      final dateKey = DateTime(
        intake.logicalDate.year,
        intake.logicalDate.month,
        intake.logicalDate.day,
      );
      byDate.putIfAbsent(dateKey, () => []).add(intake);
    }

    // Sort dates ascending
    final sortedDates = byDate.keys.toList()..sort();
    int currentStreak = 0;
    int bestStreak = 0;
    int tempStreak = 0;

    // Compute best streak historically
    for (final date in sortedDates) {
      final dayIntakes = byDate[date]!;
      final dayTaken = dayIntakes.where((i) => i.status == IntakeStatus.taken).length;
      final dayDecisive = dayIntakes.where((i) => i.status != IntakeStatus.pending).length;

      final isSuccessfulDay = dayDecisive > 0 && dayTaken == dayDecisive;
      if (isSuccessfulDay) {
        tempStreak++;
        if (tempStreak > bestStreak) {
          bestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }

    // Compute current active streak counting backwards from logical today
    final now = DateTime.now();
    final logicalToday = MedicationIntake.getLogicalDate(now);
    final todayKey = DateTime(logicalToday.year, logicalToday.month, logicalToday.day);

    DateTime checkDate = todayKey;
    while (true) {
      final dayIntakes = byDate[checkDate];
      if (dayIntakes == null || dayIntakes.isEmpty) {
        // If checking today and no intakes yet today, check yesterday before breaking
        if (checkDate == todayKey) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }

      final dayTaken = dayIntakes.where((i) => i.status == IntakeStatus.taken).length;
      final dayMissed = dayIntakes.where((i) => i.status == IntakeStatus.missed).length;
      final daySkipped = dayIntakes.where((i) => i.status == IntakeStatus.skipped).length;

      // If today has pending doses but no misses/skips, don't break current streak yet
      if (checkDate == todayKey && dayMissed == 0 && daySkipped == 0) {
        if (dayTaken > 0) currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      if (dayMissed == 0 && daySkipped == 0 && dayTaken > 0) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    if (bestStreak < currentStreak) {
      bestStreak = currentStreak;
    }

    // 3. Total Active Substance Volume
    final totalDosage = taken.fold<double>(0.0, (acc, item) {
      return acc + (item.dosageTaken ?? medication.dosage);
    });

    // 4. Day of the Week Distribution (0 = Monday .. 6 = Sunday)
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<DayOfWeekStats> dayStats = [];
    for (int day = 0; day < 7; day++) {
      // DateTime weekday in Dart is 1 = Monday .. 7 = Sunday
      final targetWeekday = day + 1;
      final dayIntakes = history.where((i) => i.logicalDate.weekday == targetWeekday).toList();
      final dayTakenCount = dayIntakes.where((i) => i.status == IntakeStatus.taken).length;
      dayStats.add(DayOfWeekStats(
        dayIndex: day,
        dayName: dayNames[day],
        totalScheduled: dayIntakes.length,
        takenCount: dayTakenCount,
      ));
    }

    // 5. Circadian / Time of Day Distribution
    final Map<String, List<MedicationIntake>> timeGroups = {
      'Morning': [],
      'Afternoon': [],
      'Evening': [],
      'Night': [],
    };

    for (final intake in history) {
      final hour = intake.scheduledTime.hour;
      if (hour >= 5 && hour < 12) {
        timeGroups['Morning']!.add(intake);
      } else if (hour >= 12 && hour < 17) {
        timeGroups['Afternoon']!.add(intake);
      } else if (hour >= 17 && hour < 21) {
        timeGroups['Evening']!.add(intake);
      } else {
        timeGroups['Night']!.add(intake);
      }
    }

    final List<TimeOfDayStats> timeOfDayList = [
      TimeOfDayStats(
        title: 'Morning',
        timeRange: '5:00 AM - 12:00 PM',
        totalScheduled: timeGroups['Morning']!.length,
        takenCount: timeGroups['Morning']!.where((i) => i.status == IntakeStatus.taken).length,
      ),
      TimeOfDayStats(
        title: 'Afternoon',
        timeRange: '12:00 PM - 5:00 PM',
        totalScheduled: timeGroups['Afternoon']!.length,
        takenCount: timeGroups['Afternoon']!.where((i) => i.status == IntakeStatus.taken).length,
      ),
      TimeOfDayStats(
        title: 'Evening',
        timeRange: '5:00 PM - 9:00 PM',
        totalScheduled: timeGroups['Evening']!.length,
        takenCount: timeGroups['Evening']!.where((i) => i.status == IntakeStatus.taken).length,
      ),
      TimeOfDayStats(
        title: 'Night',
        timeRange: '9:00 PM - 5:00 AM',
        totalScheduled: timeGroups['Night']!.length,
        takenCount: timeGroups['Night']!.where((i) => i.status == IntakeStatus.taken).length,
      ),
    ];

    // 6. Trend data for last 14 and 30 days
    final List<DailyAdherencePoint> trend14 = [];
    final List<DailyAdherencePoint> trend30 = [];

    for (int i = 13; i >= 0; i--) {
      final date = logicalToday.subtract(Duration(days: i));
      final dateKey = DateTime(date.year, date.month, date.day);
      final dayIntakes = byDate[dateKey] ?? [];
      trend14.add(DailyAdherencePoint(
        date: dateKey,
        total: dayIntakes.length,
        taken: dayIntakes.where((item) => item.status == IntakeStatus.taken).length,
        missed: dayIntakes.where((item) => item.status == IntakeStatus.missed).length,
        skipped: dayIntakes.where((item) => item.status == IntakeStatus.skipped).length,
      ));
    }

    for (int i = 29; i >= 0; i--) {
      final date = logicalToday.subtract(Duration(days: i));
      final dateKey = DateTime(date.year, date.month, date.day);
      final dayIntakes = byDate[dateKey] ?? [];
      trend30.add(DailyAdherencePoint(
        date: dateKey,
        total: dayIntakes.length,
        taken: dayIntakes.where((item) => item.status == IntakeStatus.taken).length,
        missed: dayIntakes.where((item) => item.status == IntakeStatus.missed).length,
        skipped: dayIntakes.where((item) => item.status == IntakeStatus.skipped).length,
      ));
    }

    // 7. Clinical Observations / Automated Insights
    final List<String> insights = [];
    if (total == 0) {
      insights.add('No intake logs recorded yet. Start taking scheduled doses to generate adherence insights.');
    } else {
      if (adherence >= 0.90) {
        insights.add('🌟 Outstanding clinical adherence (${(adherence * 100).toInt()}%). Maintain this consistent routine for optimal therapeutic outcomes.');
      } else if (adherence >= 0.75) {
        insights.add('👍 Solid adherence (${(adherence * 100).toInt()}%). Aim to reduce occasional missed doses for maximum pharmacological effectiveness.');
      } else {
        insights.add('⚠️ Adherence is currently at ${(adherence * 100).toInt()}%. Consider adjusting reminder notifications to keep from missing doses.');
      }

      if (currentStreak >= 7) {
        insights.add('🔥 $currentStreak-day active streak! You are maintaining an exceptional chronotherapy regimen.');
      }

      if (onTimePct >= 0.85 && taken.isNotEmpty) {
        insights.add('⏱️ High dosing punctuality: ${(onTimePct * 100).toInt()}% of doses are taken within 30 minutes of scheduled time.');
      } else if (delayed > 0 || significantlyDelayed > 0) {
        insights.add('🕒 Average dose timing deviation is ${avgDelay.toInt()} minutes. Taking medication at steady intervals ensures consistent plasma concentration.');
      }

      // Check weekend vs weekday performance
      final weekendTotal = dayStats[5].totalScheduled + dayStats[6].totalScheduled;
      final weekendTaken = dayStats[5].takenCount + dayStats[6].takenCount;
      final weekdayTotal = dayStats.take(5).fold(0, (acc, item) => acc + item.totalScheduled);
      final weekdayTaken = dayStats.take(5).fold(0, (acc, item) => acc + item.takenCount);

      if (weekendTotal > 0 && weekdayTotal > 0) {
        final weekendRate = weekendTaken / weekendTotal;
        final weekdayRate = weekdayTaken / weekdayTotal;
        if (weekdayRate - weekendRate > 0.20) {
          insights.add('📅 Weekend dip detected: adherence is significantly higher on weekdays than weekends. Weekend reminders can help bridge this gap.');
        }
      }
    }

    return MedicationAnalyticsData(
      medication: medication,
      schedule: schedule,
      totalScheduled: total,
      takenCount: taken.length,
      skippedCount: skipped.length,
      missedCount: missed.length,
      pendingCount: pending.length,
      adherenceRate: adherence,
      complianceRate: compliance,
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
      totalDosageConsumed: totalDosage,
      averageDelayMinutes: avgDelay,
      onTimeCount: onTime,
      delayedCount: delayed,
      significantlyDelayedCount: significantlyDelayed,
      earlyCount: early,
      onTimePercentage: onTimePct,
      dayOfWeekStats: dayStats,
      timeOfDayStats: timeOfDayList,
      dailyTrendLast14Days: trend14,
      dailyTrendLast30Days: trend30,
      clinicalInsights: insights,
    );
  }
}
