import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medday_flow/services/native_preferences_service.dart';
import 'package:medday_flow/utils/catalog.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';

/// Notification modes calibrated to user adherence patterns.
enum NotificationProfile {
  calm,
  standard,
  supportive,
}

/// Notification configuration based on historical adherence.
@immutable
class NotificationProfileConfig {
  final NotificationProfile profile;
  final double adherenceRate;
  final int totalScheduledDoses;
  final int takenDoses;
  final String? dropOffTimeWindow;
  final int preDoseLeadMinutes;
  final bool followUpCheckInEnabled;

  const NotificationProfileConfig({
    required this.profile,
    required this.adherenceRate,
    required this.totalScheduledDoses,
    required this.takenDoses,
    this.dropOffTimeWindow,
    required this.preDoseLeadMinutes,
    required this.followUpCheckInEnabled,
  });

  String get displayLabel {
    switch (profile) {
      case NotificationProfile.calm:
        return 'Calm';
      case NotificationProfile.standard:
        return 'Standard';
      case NotificationProfile.supportive:
        return 'Supportive';
    }
  }

  String get description {
    switch (profile) {
      case NotificationProfile.calm:
        return 'Single reminder, no follow-up nags (High Adherence)';
      case NotificationProfile.standard:
        return 'Normal reminder with standard snooze';
      case NotificationProfile.supportive:
        final windowText = dropOffTimeWindow != null ? ' ($dropOffTimeWindow window)' : '';
        return 'Gentle 15m heads-up & check-ins enabled$windowText';
    }
  }
}

/// Suggestion to adapt medication reminder time to actual completion habits.
@immutable
class ReminderShiftSuggestion {
  final String medicationId;
  final String medicationName;
  final String? scheduleId;
  final TimeOfDay currentTime;
  final TimeOfDay suggestedTime;
  final int averageOffsetMinutes;
  final int sampleCount;
  final double iqrMinutes;

  const ReminderShiftSuggestion({
    required this.medicationId,
    required this.medicationName,
    this.scheduleId,
    required this.currentTime,
    required this.suggestedTime,
    required this.averageOffsetMinutes,
    required this.sampleCount,
    required this.iqrMinutes,
  });

  String _formatTime(TimeOfDay t) {
    final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get formattedCurrentTime => _formatTime(currentTime);
  String get formattedSuggestedTime => _formatTime(suggestedTime);

  String get explanation {
    final sign = averageOffsetMinutes > 0 ? '+' : '';
    return 'You usually take $medicationName around $formattedSuggestedTime ($sign${averageOffsetMinutes}m). Shift reminder to $formattedSuggestedTime?';
  }
}

/// Suggestion to calibrate waking-day circadian cutoff hour.
@immutable
class CircadianCutoffSuggestion {
  final int currentCutoffHour;
  final int suggestedCutoffHour;
  final int lateNightCount;

  const CircadianCutoffSuggestion({
    required this.currentCutoffHour,
    required this.suggestedCutoffHour,
    required this.lateNightCount,
  });

  String get formattedCurrentHour => '${currentCutoffHour == 0 ? 12 : currentCutoffHour}:00 AM';
  String get formattedSuggestedHour => '${suggestedCutoffHour == 0 ? 12 : suggestedCutoffHour}:00 AM';

  String get explanation {
    return 'You logged $lateNightCount late-night doses/tasks past $formattedCurrentHour. Shift your day cutoff to $formattedSuggestedHour?';
  }
}

/// Categorization of items ranked for smart "Up Next" presentation.
enum RankedItemType {
  medication,
  task,
}

/// Prioritized item surfaced dynamically for the waking day.
@immutable
class RankedUpNextItem {
  final String id;
  final String title;
  final String subtitle;
  final RankedItemType type;
  final DateTime scheduledTime;
  final double priorityScore;
  final MedicationIntake? medicationIntake;
  final Task? task;
  final String reason;

  const RankedUpNextItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.scheduledTime,
    required this.priorityScore,
    this.medicationIntake,
    this.task,
    required this.reason,
  });
}

/// Usage-based personalization engine for MedDay Flow.
/// Deterministic, pure-Dart implementation with zero external dependencies.
class PersonalizationService {
  PersonalizationService._();

  static const String prefKeyPersonalizationEnabled = 'smart_personalization_enabled';
  static const String prefKeyCircadianCutoff = 'user_circadian_cutoff_hour';
  static const String _prefixShiftDismiss = 'dismissed_shift_';
  static const String _prefixCircadianDismiss = 'dismissed_circadian_';

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. ADAPTIVE REMINDER TIMING (analyzeReminderShift)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Analyzes rolling 14-day completion timestamps vs. scheduled reminder times.
  /// If >= 5 logged doses have median offset >= 15 min with low variance (IQR <= 20 min),
  /// emits a [ReminderShiftSuggestion].
  static ReminderShiftSuggestion? analyzeReminderShift({
    required List<MedicationIntake> history,
    required String medicationId,
    required String medicationName,
    MedicationSchedule? schedule,
    DateTime? referenceNow,
    Set<String> dismissedMedicationIds = const {},
  }) {
    if (dismissedMedicationIds.contains(medicationId)) {
      return null;
    }

    final now = referenceNow ?? DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final windowStart = startOfToday.subtract(const Duration(days: 14));

    // Filter relevant taken doses with non-null actual time within 14 days
    final validDoses = history.where((intake) {
      if (intake.schedule.medication.medicationId != medicationId) return false;
      if (intake.status != IntakeStatus.taken) return false;
      if (intake.actualTime == null) return false;
      // Handle missing scheduled time safely
      final st = intake.scheduledTime;
      return st.isAfter(windowStart) && st.isBefore(now.add(const Duration(hours: 1)));
    }).toList();

    if (validDoses.length < 5) {
      return null;
    }

    // Calculate signed offset in minutes (actual - scheduled)
    final List<int> offsets = [];
    for (final intake in validDoses) {
      final actual = intake.actualTime!;
      final scheduled = intake.scheduledTime;
      final diffMinutes = actual.difference(scheduled).inMinutes;

      // Filter extreme multi-hour outliers (> 4 hours) that indicate distinct dose sessions
      if (diffMinutes.abs() <= 240) {
        offsets.add(diffMinutes);
      }
    }

    if (offsets.length < 5) {
      return null;
    }

    offsets.sort();

    // Calculate Median
    final median = _calculateMedian(offsets);

    // Calculate IQR (Interquartile Range)
    final iqr = _calculateIQR(offsets);

    // Criteria: Median offset >= 15 min (earlier or later) with low variance (IQR <= 20 min)
    if (median.abs() < 15 || iqr > 20) {
      return null;
    }

    // Determine current scheduled reference time
    TimeOfDay currentTime;
    if (schedule != null && schedule.timesPerDay.isNotEmpty) {
      currentTime = schedule.timesPerDay.first;
    } else if (validDoses.isNotEmpty) {
      currentTime = TimeOfDay(
        hour: validDoses.first.scheduledTime.hour,
        minute: validDoses.first.scheduledTime.minute,
      );
    } else {
      currentTime = const TimeOfDay(hour: 8, minute: 0);
    }

    // Compute suggested time by adding median offset
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    var suggestedMinutes = (currentMinutes + median.round()) % 1440;
    if (suggestedMinutes < 0) suggestedMinutes += 1440;

    final suggestedTime = TimeOfDay(
      hour: suggestedMinutes ~/ 60,
      minute: suggestedMinutes % 60,
    );

    // If suggested time is identical to current time, no suggestion needed
    if (suggestedTime.hour == currentTime.hour && suggestedTime.minute == currentTime.minute) {
      return null;
    }

    return ReminderShiftSuggestion(
      medicationId: medicationId,
      medicationName: medicationName,
      scheduleId: schedule?.scheduleId,
      currentTime: currentTime,
      suggestedTime: suggestedTime,
      averageOffsetMinutes: median.round(),
      sampleCount: offsets.length,
      iqrMinutes: iqr,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. AUTO-CALIBRATED CIRCADIAN CUTOFF (analyzeCircadianCutoff)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Analyzes late-night intake and task completion timestamps between 12:00 AM and 5:59 AM
  /// over the rolling 14-day window.
  /// If user logs >= 4 actions within 45 minutes past current waking-day cutoff,
  /// emits [CircadianCutoffSuggestion] capped between 2:00 AM and 6:00 AM.
  static CircadianCutoffSuggestion? analyzeCircadianCutoff({
    required List<MedicationIntake> medicationHistory,
    required List<Task> taskHistory,
    int currentCutoffHour = MedicationIntake.defaultCircadianCutoffHour,
    DateTime? referenceNow,
    Set<int> dismissedCutoffHours = const {},
  }) {
    final now = referenceNow ?? DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final windowStart = startOfToday.subtract(const Duration(days: 14));

    // Target window: 45 minutes past currentCutoffHour
    final cutoffStartMinutes = currentCutoffHour * 60;
    final cutoffEndMinutes = cutoffStartMinutes + 45;

    int lateNightActionsCount = 0;

    // 1. Analyze medication completions
    for (final intake in medicationHistory) {
      if (intake.status != IntakeStatus.taken || intake.actualTime == null) continue;
      final takenAt = intake.actualTime!;
      if (takenAt.isBefore(windowStart) || takenAt.isAfter(now)) continue;

      // Check if between 12:00 AM (00:00) and 5:59 AM (05:59)
      if (takenAt.hour >= 0 && takenAt.hour < 6) {
        final minuteOfDay = takenAt.hour * 60 + takenAt.minute;
        if (minuteOfDay >= cutoffStartMinutes && minuteOfDay <= cutoffEndMinutes) {
          lateNightActionsCount++;
        }
      }
    }

    // 2. Analyze task completions
    for (final task in taskHistory) {
      final List<DateTime> timestamps = [];
      if (task.completedAt != null) {
        timestamps.add(task.completedAt!);
      }
      for (final stamp in task.completionStamps) {
        timestamps.add(stamp);
      }

      for (final stamp in timestamps) {
        if (stamp.isBefore(windowStart) || stamp.isAfter(now)) continue;
        if (stamp.hour >= 0 && stamp.hour < 6) {
          final minuteOfDay = stamp.hour * 60 + stamp.minute;
          if (minuteOfDay >= cutoffStartMinutes && minuteOfDay <= cutoffEndMinutes) {
            lateNightActionsCount++;
          }
        }
      }
    }

    // Threshold: >= 4 late-night actions within 45 minutes past cutoff
    if (lateNightActionsCount >= 4) {
      final suggestedCutoff = (currentCutoffHour + 1).clamp(2, 6);
      if (suggestedCutoff > currentCutoffHour && !dismissedCutoffHours.contains(suggestedCutoff)) {
        return CircadianCutoffSuggestion(
          currentCutoffHour: currentCutoffHour,
          suggestedCutoffHour: suggestedCutoff,
          lateNightCount: lateNightActionsCount,
        );
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. SMART "UP NEXT" PRIORITIZATION (rankUpNextItems)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Ranks pending medications and tasks for the current waking day deterministically
  /// based on proximity, completion affinity for current hour bucket (+/- 1 hr), and urgency.
  static List<RankedUpNextItem> rankUpNextItems({
    required List<MedicationIntake> pendingMedications,
    required List<Task> pendingTasks,
    List<MedicationIntake> historyMedications = const [],
    List<Task> historyTasks = const [],
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final currentHour = now.hour;
    final hourBucket = [
      (currentHour - 1 + 24) % 24,
      currentHour,
      (currentHour + 1) % 24,
    ];

    final List<RankedUpNextItem> ranked = [];

    // 1. Score pending medications
    for (final intake in pendingMedications) {
      if (intake.status != IntakeStatus.pending) continue;

      final scheduled = intake.scheduledTime;
      final diffMinutes = scheduled.difference(now).inMinutes;
      final isOverdue = diffMinutes < 0;

      // Base urgency/proximity score
      double baseScore;
      String reason;
      if (isOverdue) {
        final overdueMinutes = -diffMinutes;
        baseScore = 100.0 + (overdueMinutes.clamp(0, 360) / 10.0);
        reason = 'Overdue by ${_formatDuration(overdueMinutes)}';
      } else {
        baseScore = (60.0 - diffMinutes.clamp(0, 720) * (60.0 / 720.0)).clamp(0.0, 60.0);
        if (diffMinutes <= 30) {
          baseScore += 25.0; // Due soon boost
          reason = 'Due now';
        } else {
          reason = 'Scheduled in ${_formatDuration(diffMinutes)}';
        }
      }

      // Historical completion affinity boost
      final medId = intake.schedule.medication.medicationId;
      final affinityMatches = historyMedications.where((h) {
        if (h.schedule.medication.medicationId != medId) return false;
        if (h.actualTime == null) return false;
        return hourBucket.contains(h.actualTime!.hour);
      }).length;

      final affinityBoost = (affinityMatches * 4.0).clamp(0.0, 30.0);
      if (affinityBoost > 0) {
        reason += ' • Habitual completion window';
      }

      final totalScore = baseScore + affinityBoost;

      ranked.add(RankedUpNextItem(
        id: intake.intakeId,
        title: intake.schedule.medication.name,
        subtitle: '${intake.schedule.medication.dosage} ${intake.schedule.medication.unit.name}',
        type: RankedItemType.medication,
        scheduledTime: scheduled,
        priorityScore: totalScore,
        medicationIntake: intake,
        reason: reason,
      ));
    }

    // 2. Score pending tasks
    for (final task in pendingTasks) {
      if (task.isCompleted) continue;

      // Safely deduce scheduled time
      DateTime scheduled;
      if (task.date != null) {
        final timeMap = task.safeNotificationRecurrenceTime;
        final h = timeMap['hour'] ?? 9;
        final m = timeMap['minute'] ?? 0;
        scheduled = DateTime(task.date!.year, task.date!.month, task.date!.day, h, m);
      } else {
        scheduled = now;
      }

      final diffMinutes = scheduled.difference(now).inMinutes;
      final isOverdue = diffMinutes < 0 && scheduled.isBefore(now);

      double baseScore;
      String reason;
      if (isOverdue) {
        final overdueMinutes = -diffMinutes;
        baseScore = 95.0 + (overdueMinutes.clamp(0, 360) / 10.0);
        reason = 'Overdue by ${_formatDuration(overdueMinutes)}';
      } else {
        baseScore = (55.0 - diffMinutes.clamp(0, 720) * (55.0 / 720.0)).clamp(0.0, 55.0);
        if (diffMinutes <= 30 && diffMinutes >= -15) {
          baseScore += 20.0;
          reason = 'Due now';
        } else {
          reason = 'Scheduled in ${_formatDuration(diffMinutes)}';
        }
      }

      // Historical task affinity
      final affinityMatches = historyTasks.where((t) {
        if (t.completedAt != null && hourBucket.contains(t.completedAt!.hour)) {
          return true;
        }
        return t.completionStamps.any((s) => hourBucket.contains(s.hour));
      }).length;

      final affinityBoost = (affinityMatches * 2.5).clamp(0.0, 25.0);
      if (affinityBoost > 0) {
        reason += ' • Habitual completion window';
      }

      final totalScore = baseScore + affinityBoost;

      ranked.add(RankedUpNextItem(
        id: task.docId ?? 'task_${task.title}',
        title: task.title,
        subtitle: task.detail.isNotEmpty ? task.detail : 'Scheduled task',
        type: RankedItemType.task,
        scheduledTime: scheduled,
        priorityScore: totalScore,
        task: task,
        reason: reason,
      ));
    }

    // 3. Deterministic Sort:
    // Highest priority score first -> earliest scheduled time -> alphabetical by ID
    ranked.sort((a, b) {
      final scoreComparison = b.priorityScore.compareTo(a.priorityScore);
      if (scoreComparison != 0) return scoreComparison;

      final timeComparison = a.scheduledTime.compareTo(b.scheduledTime);
      if (timeComparison != 0) return timeComparison;

      return a.id.compareTo(b.id);
    });

    return ranked;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. ADHERENCE-AWARE NOTIFICATION MODE (computeNotificationProfile)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Calculates rolling 7-day adherence rate (excluding PRN doses) and outputs
  /// the corresponding [NotificationProfileConfig].
  static NotificationProfileConfig computeNotificationProfile({
    required List<MedicationIntake> history,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final windowStart = startOfToday.subtract(const Duration(days: 7));

    // Exclude PRN (as-needed) medications
    final eligibleDoses = history.where((intake) {
      if (intake.schedule.frequency == MedicationFrequency.asNeeded) return false;
      final st = intake.scheduledTime;
      return st.isAfter(windowStart) && st.isBefore(now.add(const Duration(hours: 1)));
    }).toList();

    final totalScheduled = eligibleDoses.length;
    final takenCount = eligibleDoses.where((i) => i.status == IntakeStatus.taken).length;
    final adherenceRate = totalScheduled > 0 ? (takenCount / totalScheduled) : 1.0;

    NotificationProfile profile;
    if (totalScheduled < 5) {
      // Not enough data yet -> Standard mode
      profile = NotificationProfile.standard;
    } else if (adherenceRate >= 0.90) {
      // Calm mode: >= 90% adherence
      profile = NotificationProfile.calm;
    } else if (adherenceRate >= 0.70) {
      // Standard mode: 70%–89% adherence
      profile = NotificationProfile.standard;
    } else {
      // Supportive mode: < 70% adherence
      profile = NotificationProfile.supportive;
    }

    // Determine highest-miss time window if supportive
    String? dropOffWindow;
    int preDoseLeadMinutes = 0;
    bool followUpCheckInEnabled = false;

    if (profile == NotificationProfile.supportive) {
      preDoseLeadMinutes = 15;
      followUpCheckInEnabled = true;

      final Map<String, int> missCounts = {
        'morning': 0,
        'afternoon': 0,
        'evening': 0,
        'night': 0,
      };

      for (final intake in eligibleDoses) {
        if (intake.status != IntakeStatus.taken) {
          final h = intake.scheduledTime.hour;
          if (h >= 5 && h < 12) {
            missCounts['morning'] = missCounts['morning']! + 1;
          } else if (h >= 12 && h < 17) {
            missCounts['afternoon'] = missCounts['afternoon']! + 1;
          } else if (h >= 17 && h < 22) {
            missCounts['evening'] = missCounts['evening']! + 1;
          } else {
            missCounts['night'] = missCounts['night']! + 1;
          }
        }
      }

      var maxMisses = -1;
      for (final entry in missCounts.entries) {
        if (entry.value > maxMisses) {
          maxMisses = entry.value;
          dropOffWindow = entry.key;
        }
      }
    }

    return NotificationProfileConfig(
      profile: profile,
      adherenceRate: adherenceRate,
      totalScheduledDoses: totalScheduled,
      takenDoses: takenCount,
      dropOffTimeWindow: dropOffWindow,
      preDoseLeadMinutes: preDoseLeadMinutes,
      followUpCheckInEnabled: followUpCheckInEnabled,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PREFERENCE PERSISTENCE & DISMISSAL MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────────

  /// Checks if smart personalization is enabled by user preference (default true).
  static Future<bool> isPersonalizationEnabled() async {
    final prefs = await NativePreferencesService.getInstance();
    return prefs.getBool(prefKeyPersonalizationEnabled) ?? true;
  }

  /// Sets smart personalization enabled/disabled.
  static Future<void> setPersonalizationEnabled(bool enabled) async {
    final prefs = await NativePreferencesService.getInstance();
    await prefs.setBool(prefKeyPersonalizationEnabled, enabled);
  }

  /// Gets current circadian cutoff hour (default 4).
  static Future<int> getCircadianCutoffHour() async {
    final prefs = await NativePreferencesService.getInstance();
    return prefs.getInt(prefKeyCircadianCutoff) ?? MedicationIntake.defaultCircadianCutoffHour;
  }

  /// Sets circadian cutoff hour.
  static Future<void> setCircadianCutoffHour(int hour) async {
    final prefs = await NativePreferencesService.getInstance();
    await prefs.setInt(prefKeyCircadianCutoff, hour.clamp(2, 6));
  }

  /// Snoozes/dismisses a reminder shift suggestion for 14 days.
  static Future<void> dismissReminderShift(
    String medicationId, [
    Duration duration = const Duration(days: 14),
  ]) async {
    final prefs = await NativePreferencesService.getInstance();
    final expiry = DateTime.now().add(duration).millisecondsSinceEpoch;
    await prefs.setInt('$_prefixShiftDismiss$medicationId', expiry);
  }

  /// Snoozes/dismisses a circadian cutoff suggestion for 14 days.
  static Future<void> dismissCircadianCutoff(
    int suggestedHour, [
    Duration duration = const Duration(days: 14),
  ]) async {
    final prefs = await NativePreferencesService.getInstance();
    final expiry = DateTime.now().add(duration).millisecondsSinceEpoch;
    await prefs.setInt('$_prefixCircadianDismiss$suggestedHour', expiry);
  }

  /// Reads dismissed medication IDs that haven't expired yet.
  static Future<Set<String>> getActiveDismissedReminderShifts() async {
    final prefs = await NativePreferencesService.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final Set<String> result = {};

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefixShiftDismiss)) {
        final expiry = prefs.getInt(key) ?? 0;
        if (expiry > now) {
          result.add(key.replaceFirst(_prefixShiftDismiss, ''));
        }
      }
    }
    return result;
  }

  /// Reads dismissed circadian cutoff hours that haven't expired yet.
  static Future<Set<int>> getActiveDismissedCircadianCutoffs() async {
    final prefs = await NativePreferencesService.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final Set<int> result = {};

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefixCircadianDismiss)) {
        final expiry = prefs.getInt(key) ?? 0;
        if (expiry > now) {
          final hour = int.tryParse(key.replaceFirst(_prefixCircadianDismiss, ''));
          if (hour != null) result.add(hour);
        }
      }
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STATISTICAL HELPERS
  // ─────────────────────────────────────────────────────────────────────────────

  static double _calculateMedian(List<int> sorted) {
    final n = sorted.length;
    if (n == 0) return 0.0;
    if (n % 2 == 1) {
      return sorted[n ~/ 2].toDouble();
    } else {
      return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
    }
  }

  static double _calculateIQR(List<int> sorted) {
    final n = sorted.length;
    if (n < 4) return 0.0;

    List<int> lowerHalf;
    List<int> upperHalf;

    if (n % 2 == 0) {
      lowerHalf = sorted.sublist(0, n ~/ 2);
      upperHalf = sorted.sublist(n ~/ 2);
    } else {
      lowerHalf = sorted.sublist(0, n ~/ 2);
      upperHalf = sorted.sublist(n ~/ 2 + 1);
    }

    final q1 = _calculateMedian(lowerHalf);
    final q3 = _calculateMedian(upperHalf);
    return max(0.0, q3 - q1);
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }
}
