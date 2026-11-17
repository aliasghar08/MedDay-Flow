import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:medday_flow/services/medication_analytics_service.dart';
import 'package:medday_flow/services/medication_ml_classifier_service.dart';
import 'package:medday_flow/services/medication_pdf_report_service.dart';
import 'package:medday_flow/widgets/medication_pill_graphic.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_classes.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MedicationClassCatalog Tests', () {
    test('Catalog contains more than 50 standardized medical classes', () {
      expect(MedicationClassCatalog.classes.length, greaterThanOrEqualTo(50));
    });

    test('All classes have valid attributes (id, name, category, examples, color, icon)', () {
      for (final c in MedicationClassCatalog.classes) {
        expect(c.id.isNotEmpty, isTrue);
        expect(c.name.isNotEmpty, isTrue);
        expect(c.category.isNotEmpty, isTrue);
        expect(c.examples.isNotEmpty, isTrue);
        expect(c.colorHex.startsWith('#'), isTrue);
        expect(c.icon.isNotEmpty, isTrue);
      }
    });

    test('Search matching works on class name, category, and generic drug examples', () {
      final statin = MedicationClassCatalog.classes.firstWhere((c) => c.id == 'statin');
      expect(statin.matches('statin'), isTrue);
      expect(statin.matches('Cardiovascular'), isTrue);
      expect(statin.matches('Atorvastatin'), isTrue);
      expect(statin.matches('nonexistentquery123'), isFalse);
    });

    test('findByName resolves existing class names accurately', () {
      final result = MedicationClassCatalog.findByName('Statin / Lipid Lowering (Cholesterol)');
      expect(result, isNotNull);
      expect(result!.id, equals('statin'));
    });
  });

  group('MedicationAnalyticsService Tests', () {
    late Medication testMed;
    late MedicationSchedule testSchedule;

    setUp(() {
      testMed = Medication(
        medicationId: 'med_test_1',
        name: 'Amlodipine',
        dosage: 5.0,
        unit: DosageUnit.mg,
        medicationClass: 'Antihypertensive (General BP)',
        formula: 'Amlodipine Besylate',
      );

      testSchedule = MedicationSchedule(
        scheduleId: 'sched_test_1',
        medication: testMed,
        startDate: DateTime(2026, 1, 1),
        frequency: MedicationFrequency.daily,
        timesPerDay: [const TimeOfDay(hour: 8, minute: 0)],
      );
    });

    test('Calculates adherence rate, status breakdown, and volume correctly', () {
      final day1 = DateTime(2026, 11, 10, 8, 0);
      final day2 = DateTime(2026, 11, 11, 8, 0);
      final day3 = DateTime(2026, 11, 12, 8, 0);
      final day4 = DateTime(2026, 11, 13, 8, 0);

      final history = [
        MedicationIntake(
          schedule: testSchedule,
          scheduledTime: day1,
          actualTime: day1.add(const Duration(minutes: 5)),
          status: IntakeStatus.taken,
          dosageTaken: 5.0,
        ),
        MedicationIntake(
          schedule: testSchedule,
          scheduledTime: day2,
          actualTime: day2.add(const Duration(minutes: 10)),
          status: IntakeStatus.taken,
          dosageTaken: 5.0,
        ),
        MedicationIntake(
          schedule: testSchedule,
          scheduledTime: day3,
          status: IntakeStatus.skipped,
        ),
        MedicationIntake(
          schedule: testSchedule,
          scheduledTime: day4,
          status: IntakeStatus.missed,
        ),
      ];

      final analytics = MedicationAnalyticsService.computeAnalytics(
        medication: testMed,
        history: history,
        schedule: testSchedule,
      );

      expect(analytics.totalScheduled, equals(4));
      expect(analytics.takenCount, equals(2));
      expect(analytics.skippedCount, equals(1));
      expect(analytics.missedCount, equals(1));
      expect(analytics.adherenceRate, equals(0.5));
      expect(analytics.totalDosageConsumed, equals(10.0));
      expect(analytics.onTimeCount, equals(2));
      expect(analytics.onTimePercentage, equals(1.0));
      expect(analytics.dayOfWeekStats.length, equals(7));
      expect(analytics.timeOfDayStats.length, equals(4));
      expect(analytics.clinicalInsights.isNotEmpty, isTrue);
    });
  });

  group('MedicationPdfReportService Tests', () {
    test('Generates valid PDF document with header, charts, and history table', () async {
      final testMed = Medication(
        medicationId: 'med_pdf_1',
        name: 'Metformin',
        dosage: 500.0,
        unit: DosageUnit.mg,
        medicationClass: 'Antidiabetic / Biguanide (Metformin)',
        formula: 'Metformin Hydrochloride',
      );

      final testSchedule = MedicationSchedule(
        scheduleId: 'sched_pdf_1',
        medication: testMed,
        startDate: DateTime(2026, 10, 1),
        frequency: MedicationFrequency.daily,
        timesPerDay: [const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 20, minute: 0)],
        instructions: 'Take with food and full glass of water',
      );

      final history = [
        MedicationIntake(
          schedule: testSchedule,
          scheduledTime: DateTime(2026, 11, 15, 8, 0),
          actualTime: DateTime(2026, 11, 15, 8, 12),
          status: IntakeStatus.taken,
          notes: 'Taken with breakfast',
        ),
        MedicationIntake(
          schedule: testSchedule,
          scheduledTime: DateTime(2026, 11, 15, 20, 0),
          actualTime: DateTime(2026, 11, 15, 20, 5),
          status: IntakeStatus.taken,
        ),
        MedicationIntake(
          schedule: testSchedule,
          scheduledTime: DateTime(2026, 11, 16, 8, 0),
          status: IntakeStatus.skipped,
          notes: 'Fasting for lab work',
        ),
      ];

      final bytes = await MedicationPdfReportService.generatePdfDocument(
        medication: testMed,
        history: history,
        schedule: testSchedule,
        userName: 'Dr. Jane Doe',
        userEmail: 'jane.doe@example.com',
      );

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(1000));
      // Standard PDF file header check '%PDF-'
      final header = ascii.decode(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });

  group('MedicationMLClassifierService Tests', () {
    test('Classifies known molecules accurately with 1.0 confidence and extracts dosage', () {
      final p1 = MedicationMLClassifierService.predict('Metformin HCl 500mg');
      expect(p1.hasPrediction, isTrue);
      expect(p1.predictedClass?.id, equals('antidiabetic'));
      expect(p1.confidence, equals(1.0));
      expect(p1.extractedDosage, equals(500.0));
      expect(p1.suggestedUnit, equals(DosageUnit.mg));

      final p2 = MedicationMLClassifierService.predict('Paracetamol 650 mg');
      expect(p2.hasPrediction, isTrue);
      expect(p2.predictedClass?.id, equals('analgesic_non_opioid'));
      expect(p2.extractedDosage, equals(650.0));
    });

    test('Classifies pharmacological stems accurately (statin, sartan, pril, prazole, cillin)', () {
      final statin = MedicationMLClassifierService.predict('Atorvastatin Calcium 20mg');
      expect(statin.hasPrediction, isTrue);
      expect(statin.predictedClass?.id, equals('statin'));
      expect(statin.confidence, greaterThanOrEqualTo(0.95));
      expect(statin.extractedDosage, equals(20.0));

      final sartan = MedicationMLClassifierService.predict('Losartan Potassium 50mg');
      expect(sartan.hasPrediction, isTrue);
      expect(sartan.predictedClass?.id, equals('arb'));

      final pril = MedicationMLClassifierService.predict('Lisinopril Dihydrate 10mg');
      expect(pril.hasPrediction, isTrue);
      expect(pril.predictedClass?.id, equals('ace_inhibitor'));

      final prazole = MedicationMLClassifierService.predict('Omeprazole Delayed Release Capsule 40mg');
      expect(prazole.hasPrediction, isTrue);
      expect(prazole.predictedClass?.id, equals('gastrointestinal'));
      expect(prazole.suggestedShape, equals(MedicationShape.capsule));

      final cillin = MedicationMLClassifierService.predict('Amoxicillin Trihydrate 500mg');
      expect(cillin.hasPrediction, isTrue);
      expect(cillin.predictedClass?.id, equals('antibiotic'));
    });

    test('Infers shape and dosage units from formulations (Inhaler, Drops, Syrup)', () {
      final inhaler = MedicationMLClassifierService.predict('Salbutamol Inhaler 100mcg');
      expect(inhaler.hasPrediction, isTrue);
      expect(inhaler.suggestedShape, equals(MedicationShape.inhaler));
      expect(inhaler.suggestedUnit, equals(DosageUnit.mcg));
      expect(inhaler.extractedDosage, equals(100.0));

      final drops = MedicationMLClassifierService.predict('Latanoprost Ophthalmic Eye Drops');
      expect(drops.hasPrediction, isTrue);
      expect(drops.predictedClass?.id, equals('ophthalmic'));
      expect(drops.suggestedShape, equals(MedicationShape.drops));
    });

    test('Gracefully handles empty or unknown compounds without crashing', () {
      final empty = MedicationMLClassifierService.predict('');
      expect(empty.hasPrediction, isFalse);
      expect(empty.predictedClass, isNull);

      final unknown = MedicationMLClassifierService.predict('XYZ9999_Completely_Unknown_Substance');
      expect(unknown.confidence, lessThan(0.40));
    });
  });
}
