import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medday_flow/services/native_preferences_service.dart';
import 'package:medday_flow/services/personalization_service.dart';
import 'package:medday_flow/utils/catalog.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NativePreferencesService.setMockInitialValues({});
  });

  tearDown(() {
    NativePreferencesService.reset();
  });

  // Helper to create a test medication
  Medication createTestMed({
    String id = 'med_lisinopril',
    String name = 'Lisinopril',
    double dosage = 10.0,
    DosageUnit unit = DosageUnit.mg,
  }) {
    return Medication(
      medicationId: id,
      name: name,
      dosage: dosage,
      unit: unit,
    );
  }

  // Helper to create a test schedule
  MedicationSchedule createTestSchedule({
    required Medication medication,
    String scheduleId = 'sched_lisinopril',
    List<TimeOfDay> times = const [TimeOfDay(hour: 8, minute: 0)],
    MedicationFrequency frequency = MedicationFrequency.daily,
  }) {
    return MedicationSchedule(
      scheduleId: scheduleId,
      medication: medication,
      startDate: DateTime(2026, 8, 1),
      frequency: frequency,
      timesPerDay: times,
    );
  }

  // Helper to create an intake
  MedicationIntake createTestIntake({
    required MedicationSchedule schedule,
    required DateTime scheduledTime,
    DateTime? actualTime,
    IntakeStatus status = IntakeStatus.taken,
    String? intakeId,
  }) {
    return MedicationIntake(
      intakeId: intakeId ?? 'intake_${scheduledTime.millisecondsSinceEpoch}',
      schedule: schedule,
      scheduledTime: scheduledTime,
      actualTime: actualTime,
      status: status,
    );
  }

  group('1. Adaptive Reminder Timing Engine (analyzeReminderShift)', () {
    final med = createTestMed(id: 'med_lisinopril', name: 'Lisinopril');
    final schedule = createTestSchedule(
      medication: med,
      times: [const TimeOfDay(hour: 8, minute: 0)],
    );
    final referenceNow = DateTime(2026, 8, 14, 12, 0);

    test('Consistently delayed doses (8:00 AM taken at 8:25 AM) triggers reminder shift suggestion', () {
      final List<MedicationIntake> history = [];
      // 6 doses in past 7 days, scheduled at 8:00 AM, taken at 8:25 AM (+25 min offset)
      for (int i = 1; i <= 6; i++) {
        final scheduled = DateTime(2026, 8, 7 + i, 8, 0);
        final actual = DateTime(2026, 8, 7 + i, 8, 25);
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: scheduled,
          actualTime: actual,
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeReminderShift(
        history: history,
        medicationId: 'med_lisinopril',
        medicationName: 'Lisinopril',
        schedule: schedule,
        referenceNow: referenceNow,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.medicationId, 'med_lisinopril');
      expect(suggestion.medicationName, 'Lisinopril');
      expect(suggestion.currentTime, const TimeOfDay(hour: 8, minute: 0));
      expect(suggestion.suggestedTime, const TimeOfDay(hour: 8, minute: 25));
      expect(suggestion.averageOffsetMinutes, 25);
      expect(suggestion.sampleCount, 6);
      expect(suggestion.iqrMinutes, lessThanOrEqualTo(20.0));
      expect(suggestion.explanation, contains('8:25 AM'));
    });

    test('Consistently early doses (8:00 AM taken at 7:40 AM) triggers earlier shift suggestion', () {
      final List<MedicationIntake> history = [];
      for (int i = 1; i <= 5; i++) {
        final scheduled = DateTime(2026, 8, 7 + i, 8, 0);
        final actual = DateTime(2026, 8, 7 + i, 7, 40); // -20 min offset
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: scheduled,
          actualTime: actual,
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeReminderShift(
        history: history,
        medicationId: 'med_lisinopril',
        medicationName: 'Lisinopril',
        schedule: schedule,
        referenceNow: referenceNow,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.suggestedTime, const TimeOfDay(hour: 7, minute: 40));
      expect(suggestion.averageOffsetMinutes, -20);
    });

    test('Erratic completion times with high variance (IQR > 20) emits NO suggestion', () {
      final List<MedicationIntake> history = [];
      final offsets = [-40, -10, 25, 60, 110]; // High dispersion / variance
      for (int i = 0; i < offsets.length; i++) {
        final scheduled = DateTime(2026, 8, 8 + i, 8, 0);
        final actual = scheduled.add(Duration(minutes: offsets[i]));
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: scheduled,
          actualTime: actual,
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeReminderShift(
        history: history,
        medicationId: 'med_lisinopril',
        medicationName: 'Lisinopril',
        schedule: schedule,
        referenceNow: referenceNow,
      );

      expect(suggestion, isNull);
    });

    test('Small offset (< 15 mins) emits NO suggestion', () {
      final List<MedicationIntake> history = [];
      for (int i = 1; i <= 5; i++) {
        final scheduled = DateTime(2026, 8, 7 + i, 8, 0);
        final actual = scheduled.add(const Duration(minutes: 8)); // +8 min offset
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: scheduled,
          actualTime: actual,
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeReminderShift(
        history: history,
        medicationId: 'med_lisinopril',
        medicationName: 'Lisinopril',
        schedule: schedule,
        referenceNow: referenceNow,
      );

      expect(suggestion, isNull);
    });

    test('Fewer than 5 logged doses (< 5) emits NO suggestion', () {
      final List<MedicationIntake> history = [];
      for (int i = 1; i <= 4; i++) {
        final scheduled = DateTime(2026, 8, 7 + i, 8, 0);
        final actual = scheduled.add(const Duration(minutes: 25));
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: scheduled,
          actualTime: actual,
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeReminderShift(
        history: history,
        medicationId: 'med_lisinopril',
        medicationName: 'Lisinopril',
        schedule: schedule,
        referenceNow: referenceNow,
      );

      expect(suggestion, isNull);
    });

    test('Dismissed medication ID is properly respected and suppressed', () {
      final List<MedicationIntake> history = [];
      for (int i = 1; i <= 6; i++) {
        final scheduled = DateTime(2026, 8, 7 + i, 8, 0);
        final actual = scheduled.add(const Duration(minutes: 25));
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: scheduled,
          actualTime: actual,
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeReminderShift(
        history: history,
        medicationId: 'med_lisinopril',
        medicationName: 'Lisinopril',
        schedule: schedule,
        referenceNow: referenceNow,
        dismissedMedicationIds: {'med_lisinopril'},
      );

      expect(suggestion, isNull);
    });
  });

  group('2. Auto-Calibrated Circadian Cutoff Engine (analyzeCircadianCutoff)', () {
    final med = createTestMed(id: 'med_quetiapine', name: 'Quetiapine');
    final schedule = createTestSchedule(
      medication: med,
      times: [const TimeOfDay(hour: 23, minute: 0)],
    );
    final referenceNow = DateTime(2026, 8, 14, 12, 0);

    test('Frequent late-night logs at 4:15 AM (>= 4 times within 45m past 4:00 AM) suggests 5:00 AM cutoff', () {
      final List<MedicationIntake> medHistory = [];
      final List<Task> taskHistory = [];

      // 3 bedtime doses logged at 4:15 AM
      for (int i = 1; i <= 3; i++) {
        medHistory.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 7 + i, 23, 0),
          actualTime: DateTime(2026, 8, 8 + i, 4, 15), // 4:15 AM
          status: IntakeStatus.taken,
        ));
      }

      // 1 task completed at 4:20 AM
      taskHistory.add(Task(
        docId: 'task_late_1',
        title: 'Review Journal',
        detail: 'Bedtime reflection',
        date: DateTime(2026, 8, 11),
        isCompleted: true,
        completedAt: DateTime(2026, 8, 12, 4, 20),
      ));

      final suggestion = PersonalizationService.analyzeCircadianCutoff(
        medicationHistory: medHistory,
        taskHistory: taskHistory,
        currentCutoffHour: 4,
        referenceNow: referenceNow,
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.currentCutoffHour, 4);
      expect(suggestion.suggestedCutoffHour, 5);
      expect(suggestion.lateNightCount, 4);
      expect(suggestion.explanation, contains('4:00 AM'));
      expect(suggestion.explanation, contains('5:00 AM'));
    });

    test('Capped safely at 6:00 AM bound', () {
      final List<MedicationIntake> medHistory = [];
      for (int i = 1; i <= 5; i++) {
        medHistory.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 7 + i, 23, 0),
          actualTime: DateTime(2026, 8, 8 + i, 6, 15),
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeCircadianCutoff(
        medicationHistory: medHistory,
        taskHistory: const [],
        currentCutoffHour: 6, // Already at maximum bound
        referenceNow: referenceNow,
      );

      // Cannot increase beyond 6:00 AM
      expect(suggestion, isNull);
    });

    test('Fewer than 4 late-night actions emits NO suggestion', () {
      final List<MedicationIntake> medHistory = [
        createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 8, 23, 0),
          actualTime: DateTime(2026, 8, 9, 4, 15),
          status: IntakeStatus.taken,
        ),
        createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 9, 23, 0),
          actualTime: DateTime(2026, 8, 10, 4, 15),
          status: IntakeStatus.taken,
        ),
      ];

      final suggestion = PersonalizationService.analyzeCircadianCutoff(
        medicationHistory: medHistory,
        taskHistory: const [],
        currentCutoffHour: 4,
        referenceNow: referenceNow,
      );

      expect(suggestion, isNull);
    });

    test('Dismissed cutoff hour is suppressed', () {
      final List<MedicationIntake> medHistory = [];
      for (int i = 1; i <= 5; i++) {
        medHistory.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 7 + i, 23, 0),
          actualTime: DateTime(2026, 8, 8 + i, 4, 15),
          status: IntakeStatus.taken,
        ));
      }

      final suggestion = PersonalizationService.analyzeCircadianCutoff(
        medicationHistory: medHistory,
        taskHistory: const [],
        currentCutoffHour: 4,
        referenceNow: referenceNow,
        dismissedCutoffHours: {5},
      );

      expect(suggestion, isNull);
    });
  });

  group('3. Smart "Up Next" Prioritization Engine (rankUpNextItems)', () {
    final referenceNow = DateTime(2026, 8, 14, 8, 0); // 8:00 AM

    final medMorning = createTestMed(id: 'med_morning', name: 'Thyroid Hormone');
    final schedMorning = createTestSchedule(
      medication: medMorning,
      times: [const TimeOfDay(hour: 8, minute: 0)],
    );

    final medAfternoon = createTestMed(id: 'med_afternoon', name: 'Vitamin D');
    final schedAfternoon = createTestSchedule(
      medication: medAfternoon,
      times: [const TimeOfDay(hour: 14, minute: 0)],
    );

    test('Ranks overdue and due-now items with high priority and completion affinity', () {
      final pendingIntakeMorning = createTestIntake(
        schedule: schedMorning,
        scheduledTime: DateTime(2026, 8, 14, 8, 0), // Due right now
        status: IntakeStatus.pending,
      );

      final pendingIntakeAfternoon = createTestIntake(
        schedule: schedAfternoon,
        scheduledTime: DateTime(2026, 8, 14, 14, 0), // 6 hours later
        status: IntakeStatus.pending,
      );

      final overdueTask = Task(
        docId: 'task_overdue',
        title: 'Check Blood Glucose',
        detail: 'Fasting glucose check',
        date: DateTime(2026, 8, 14),
        isCompleted: false,
        notificationRecurrenceTime: {'hour': 7, 'minute': 0}, // 1 hour overdue
      );

      // Historical completions showing user habit at 8:00 AM
      final historyMeds = [
        createTestIntake(
          schedule: schedMorning,
          scheduledTime: DateTime(2026, 8, 13, 8, 0),
          actualTime: DateTime(2026, 8, 13, 8, 5),
          status: IntakeStatus.taken,
        ),
        createTestIntake(
          schedule: schedMorning,
          scheduledTime: DateTime(2026, 8, 12, 8, 0),
          actualTime: DateTime(2026, 8, 12, 8, 2),
          status: IntakeStatus.taken,
        ),
      ];

      final ranked = PersonalizationService.rankUpNextItems(
        pendingMedications: [pendingIntakeMorning, pendingIntakeAfternoon],
        pendingTasks: [overdueTask],
        historyMedications: historyMeds,
        historyTasks: const [],
        referenceNow: referenceNow,
      );

      expect(ranked.length, 3);
      // Top items should be the overdue task or the due-now medication with affinity
      expect(ranked.first.id, isIn(['task_overdue', pendingIntakeMorning.intakeId]));
      // The afternoon dose (6 hours out) should rank last
      expect(ranked.last.id, pendingIntakeAfternoon.intakeId);
      // No items are lost or hidden
      expect(ranked.map((e) => e.id).toSet(), {
        pendingIntakeMorning.intakeId,
        pendingIntakeAfternoon.intakeId,
        'task_overdue',
      });
    });

    test('Deterministic sort order when items have equal scores', () {
      final taskA = Task(
        docId: 'task_a',
        title: 'Task A',
        detail: 'Alpha',
        date: DateTime(2026, 8, 14),
        isCompleted: false,
        notificationRecurrenceTime: {'hour': 12, 'minute': 0},
      );

      final taskB = Task(
        docId: 'task_b',
        title: 'Task B',
        detail: 'Beta',
        date: DateTime(2026, 8, 14),
        isCompleted: false,
        notificationRecurrenceTime: {'hour': 12, 'minute': 0},
      );

      final ranked = PersonalizationService.rankUpNextItems(
        pendingMedications: const [],
        pendingTasks: [taskB, taskA],
        referenceNow: referenceNow,
      );

      expect(ranked.length, 2);
      // Alphabetical by ID break ties deterministically
      expect(ranked.first.id, 'task_a');
      expect(ranked.last.id, 'task_b');
    });
  });

  group('4. Adherence-Aware Notification Mode Engine (computeNotificationProfile)', () {
    final med = createTestMed(id: 'med_statin', name: 'Atorvastatin');
    final schedule = createTestSchedule(medication: med);
    final referenceNow = DateTime(2026, 8, 14, 12, 0);

    test('High adherence (>= 90% with >= 5 doses) transitions to CALM profile', () {
      final List<MedicationIntake> history = [];
      // 10 scheduled doses, 10 taken = 100% adherence
      for (int i = 1; i <= 10; i++) {
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 7 + (i % 7), 8, 0),
          actualTime: DateTime(2026, 8, 7 + (i % 7), 8, 5),
          status: IntakeStatus.taken,
        ));
      }

      final config = PersonalizationService.computeNotificationProfile(
        history: history,
        referenceNow: referenceNow,
      );

      expect(config.profile, NotificationProfile.calm);
      expect(config.displayLabel, 'Calm');
      expect(config.preDoseLeadMinutes, 0);
      expect(config.followUpCheckInEnabled, isFalse);
      expect(config.adherenceRate, 1.0);
    });

    test('Moderate adherence (70% - 89%) transitions to STANDARD profile', () {
      final List<MedicationIntake> history = [];
      // 10 scheduled doses: 8 taken, 2 missed = 80% adherence
      for (int i = 1; i <= 10; i++) {
        final isTaken = i <= 8;
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 7 + (i % 7), 8, 0),
          actualTime: isTaken ? DateTime(2026, 8, 7 + (i % 7), 8, 5) : null,
          status: isTaken ? IntakeStatus.taken : IntakeStatus.missed,
        ));
      }

      final config = PersonalizationService.computeNotificationProfile(
        history: history,
        referenceNow: referenceNow,
      );

      expect(config.profile, NotificationProfile.standard);
      expect(config.displayLabel, 'Standard');
      expect(config.preDoseLeadMinutes, 0);
      expect(config.followUpCheckInEnabled, isFalse);
      expect(config.adherenceRate, 0.8);
    });

    test('Fewer than 5 historical doses (< 5) defaults safely to STANDARD profile', () {
      final List<MedicationIntake> history = [];
      // 3 scheduled doses: all 3 taken (100% rate, but sample < 5)
      for (int i = 1; i <= 3; i++) {
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 10 + i, 8, 0),
          actualTime: DateTime(2026, 8, 10 + i, 8, 5),
          status: IntakeStatus.taken,
        ));
      }

      final config = PersonalizationService.computeNotificationProfile(
        history: history,
        referenceNow: referenceNow,
      );

      expect(config.profile, NotificationProfile.standard);
    });

    test('Low adherence (< 70%) transitions to SUPPORTIVE profile with window detection', () {
      final List<MedicationIntake> history = [];
      // 10 scheduled morning doses (8:00 AM): only 5 taken, 5 missed = 50% adherence
      for (int i = 1; i <= 10; i++) {
        final isTaken = i <= 5;
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 7 + (i % 7), 8, 0),
          actualTime: isTaken ? DateTime(2026, 8, 7 + (i % 7), 8, 5) : null,
          status: isTaken ? IntakeStatus.taken : IntakeStatus.missed,
        ));
      }

      final config = PersonalizationService.computeNotificationProfile(
        history: history,
        referenceNow: referenceNow,
      );

      expect(config.profile, NotificationProfile.supportive);
      expect(config.displayLabel, 'Supportive');
      expect(config.preDoseLeadMinutes, 15);
      expect(config.followUpCheckInEnabled, isTrue);
      expect(config.dropOffTimeWindow, 'morning'); // Misses at 8:00 AM are 'morning'
    });

    test('PRN (as-needed) medications are excluded from adherence rate calculations', () {
      final prnSched = createTestSchedule(
        medication: med,
        frequency: MedicationFrequency.asNeeded,
      );

      final List<MedicationIntake> history = [];
      // 10 regular scheduled doses (all taken)
      for (int i = 1; i <= 10; i++) {
        history.add(createTestIntake(
          schedule: schedule,
          scheduledTime: DateTime(2026, 8, 7 + (i % 7), 8, 0),
          actualTime: DateTime(2026, 8, 7 + (i % 7), 8, 5),
          status: IntakeStatus.taken,
        ));
      }

      // 5 PRN doses that were skipped or not taken
      for (int i = 1; i <= 5; i++) {
        history.add(createTestIntake(
          schedule: prnSched,
          scheduledTime: DateTime(2026, 8, 7 + (i % 7), 12, 0),
          status: IntakeStatus.skipped,
        ));
      }

      final config = PersonalizationService.computeNotificationProfile(
        history: history,
        referenceNow: referenceNow,
      );

      // Because PRN doses are excluded, adherence is 10/10 = 100% -> CALM
      expect(config.profile, NotificationProfile.calm);
      expect(config.totalScheduledDoses, 10);
      expect(config.takenDoses, 10);
      expect(config.adherenceRate, 1.0);
    });
  });

  group('5. Null-Safety & Backward Compatibility with Legacy Firestore Records', () {
    test('Handles legacy intakes missing actualTime, notes, and dosageTaken without throwing', () {
      final med = createTestMed(id: 'med_legacy', name: 'Legacy Med');
      final sched = createTestSchedule(medication: med);

      final legacyIntake = MedicationIntake(
        intakeId: 'intake_legacy',
        schedule: sched,
        scheduledTime: DateTime(2026, 8, 14, 9, 0),
        actualTime: null,
        notes: null,
        dosageTaken: null,
        status: IntakeStatus.pending,
      );

      final shift = PersonalizationService.analyzeReminderShift(
        history: [legacyIntake],
        medicationId: 'med_legacy',
        medicationName: 'Legacy Med',
      );
      expect(shift, isNull);

      final cutoff = PersonalizationService.analyzeCircadianCutoff(
        medicationHistory: [legacyIntake],
        taskHistory: const [],
      );
      expect(cutoff, isNull);

      final ranked = PersonalizationService.rankUpNextItems(
        pendingMedications: [legacyIntake],
        pendingTasks: const [],
      );
      expect(ranked.length, 1);
      expect(ranked.first.id, 'intake_legacy');

      final profile = PersonalizationService.computeNotificationProfile(
        history: [legacyIntake],
      );
      expect(profile.profile, NotificationProfile.standard);
    });

    test('Handles legacy tasks missing optional fields without throwing', () {
      final legacyTask = Task(
        title: 'Legacy Task',
        detail: '',
        date: null,
        isCompleted: false,
        completedAt: null,
        notificationRecurrence: null,
        notificationRecurrenceTime: null,
        selectedDays: null,
      );

      final ranked = PersonalizationService.rankUpNextItems(
        pendingMedications: const [],
        pendingTasks: [legacyTask],
      );

      expect(ranked.length, 1);
      expect(ranked.first.title, 'Legacy Task');
    });

    test('Completely empty lists produce safe default outputs', () {
      expect(PersonalizationService.rankUpNextItems(
        pendingMedications: const [],
        pendingTasks: const [],
      ), isEmpty);

      final profile = PersonalizationService.computeNotificationProfile(
        history: const [],
      );
      expect(profile.profile, NotificationProfile.standard);
      expect(profile.adherenceRate, 1.0);
      expect(profile.totalScheduledDoses, 0);
    });
  });

  group('6. Preference Persistence & Dismissal Expiry Tracking', () {
    test('Personalization toggle persistence', () async {
      expect(await PersonalizationService.isPersonalizationEnabled(), isTrue);

      await PersonalizationService.setPersonalizationEnabled(false);
      expect(await PersonalizationService.isPersonalizationEnabled(), isFalse);

      await PersonalizationService.setPersonalizationEnabled(true);
      expect(await PersonalizationService.isPersonalizationEnabled(), isTrue);
    });

    test('Circadian cutoff persistence and bounds', () async {
      expect(await PersonalizationService.getCircadianCutoffHour(), 4);

      await PersonalizationService.setCircadianCutoffHour(5);
      expect(await PersonalizationService.getCircadianCutoffHour(), 5);

      // Clamped to [2, 6]
      await PersonalizationService.setCircadianCutoffHour(10);
      expect(await PersonalizationService.getCircadianCutoffHour(), 6);

      await PersonalizationService.setCircadianCutoffHour(1);
      expect(await PersonalizationService.getCircadianCutoffHour(), 2);
    });

    test('Dismissed suggestions are tracked and properly detected', () async {
      expect(await PersonalizationService.getActiveDismissedReminderShifts(), isEmpty);
      expect(await PersonalizationService.getActiveDismissedCircadianCutoffs(), isEmpty);

      await PersonalizationService.dismissReminderShift('med_metformin');
      await PersonalizationService.dismissCircadianCutoff(5);

      final dismissedMeds = await PersonalizationService.getActiveDismissedReminderShifts();
      final dismissedCutoffs = await PersonalizationService.getActiveDismissedCircadianCutoffs();

      expect(dismissedMeds, contains('med_metformin'));
      expect(dismissedCutoffs, contains(5));
    });
  });
}
