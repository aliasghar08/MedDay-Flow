import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';
import 'package:medday_flow/utils/medication_model/medication_classes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Medication & Intake Models', () {
    test('Medication serialization and deserialization with advanced formula and visual properties', () {
      final med = Medication(
        medicationId: 'med_adv_123',
        name: 'Lipitor',
        formula: 'Atorvastatin Calcium 20mg',
        medicationClass: 'Statin',
        shape: 'capsule',
        secondaryColor: '#F1F5F9',
        dosage: 20.0,
        unit: DosageUnit.mg,
        color: '#2563EB',
        icon: '💊',
        description: 'Take at night for cholesterol',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = med.toMap();
      expect(map['name'], 'Lipitor');
      expect(map['formula'], 'Atorvastatin Calcium 20mg');
      expect(map['medicationClass'], 'Statin');
      expect(map['shape'], 'capsule');
      expect(map['secondaryColor'], '#F1F5F9');
      expect(map['dosage'], 20.0);
      expect(map['unit'], 'mg');

      final fromMap = Medication.fromMap(map, 'med_adv_123');
      expect(fromMap.medicationId, 'med_adv_123');
      expect(fromMap.name, 'Lipitor');
      expect(fromMap.formula, 'Atorvastatin Calcium 20mg');
      expect(fromMap.medicationClass, 'Statin');
      expect(fromMap.shape, 'capsule');
      expect(fromMap.secondaryColor, '#F1F5F9');
      expect(fromMap.dosage, 20.0);
      expect(fromMap.unit, DosageUnit.mg);
    });

    test('MedicationClassCatalog provides comprehensive classifications', () {
      expect(MedicationClassCatalog.classes.length, greaterThanOrEqualTo(15));
      final statin = MedicationClassCatalog.findByName('Statin');
      expect(statin, isNotNull);
      expect(statin!.category, 'Cardiovascular');

      final analgesic = MedicationClassCatalog.findByName('Analgesic');
      expect(analgesic, isNotNull);
      expect(analgesic!.category, 'Pain & Fever');
    });
    test('Medication serialization and deserialization', () {
      final med = Medication(
        medicationId: 'med_123',
        name: 'Aspirin',
        dosage: 100.0,
        unit: DosageUnit.mg,
        color: '#e74c3c',
        icon: '💊',
        description: 'Take after meal',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = med.toMap();
      expect(map['name'], 'Aspirin');
      expect(map['dosage'], 100.0);
      expect(map['unit'], 'mg');

      final fromMap = Medication.fromMap(map, 'med_123');
      expect(fromMap.medicationId, 'med_123');
      expect(fromMap.name, 'Aspirin');
      expect(fromMap.dosage, 100.0);
      expect(fromMap.unit, DosageUnit.mg);
    });

    test('MedicationSchedule serialization and parsing', () {
      final med = Medication(
        medicationId: 'med_123',
        name: 'Aspirin',
        dosage: 100.0,
        unit: DosageUnit.mg,
        color: '#e74c3c',
        icon: '💊',
        createdAt: DateTime(2026, 1, 1),
      );

      final schedule = MedicationSchedule(
        scheduleId: 'sched_123',
        medication: med,
        startDate: DateTime(2026, 1, 1),
        frequency: MedicationFrequency.daily,
        timesPerDay: [const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 21, minute: 0)],
        reminderMinutesBefore: 15,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = schedule.toMap();
      expect(map['frequency'], 'daily');
      expect(map['timesPerDay'], [
        {'hour': 9, 'minute': 0},
        {'hour': 21, 'minute': 0},
      ]);

      final parsed = MedicationSchedule.fromMap(map, 'sched_123', med);
      expect(parsed.scheduleId, 'sched_123');
      expect(parsed.timesPerDay.length, 2);
      expect(parsed.timesPerDay.first.hour, 9);
      expect(parsed.timesPerDay.last.hour, 21);
    });

    test('MedicationIntake ID generation and status updates', () {
      final med = Medication(
        medicationId: 'med_123',
        name: 'Aspirin',
        dosage: 100.0,
        unit: DosageUnit.mg,
        color: '#e74c3c',
        icon: '💊',
        createdAt: DateTime(2026, 1, 1),
      );

      final schedule = MedicationSchedule(
        scheduleId: 'sched_123',
        medication: med,
        startDate: DateTime(2026, 1, 1),
        frequency: MedicationFrequency.daily,
        timesPerDay: [const TimeOfDay(hour: 8, minute: 30)],
        reminderMinutesBefore: 15,
        createdAt: DateTime(2026, 1, 1),
      );

      final scheduledTime = DateTime(2026, 8, 4, 8, 30);
      final intakeId = MedicationIntake.generateIntakeId('sched_123', scheduledTime);
      expect(intakeId, 'intake_sched_123_2026_8_4_8_30');

      final intake = MedicationIntake(
        intakeId: intakeId,
        schedule: schedule,
        scheduledTime: scheduledTime,
      );

      expect(intake.status, IntakeStatus.pending);

      final takenIntake = intake.copyWith(
        status: IntakeStatus.taken,
        actualTime: DateTime(2026, 8, 4, 8, 35),
      );

      expect(takenIntake.status, IntakeStatus.taken);
      expect(takenIntake.actualTime, isNotNull);
    });
  });
}
