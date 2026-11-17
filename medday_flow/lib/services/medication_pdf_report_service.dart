import 'dart:typed_data';
import 'package:flutter/material.dart' as material show BuildContext, ScaffoldMessenger, SnackBar, Colors, Text;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:medday_flow/services/medication_analytics_service.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';

class MedicationPdfReportService {
  /// Generates and previews/prints a clinical PDF report for a given medication
  static Future<void> exportPdfReport({
    required material.BuildContext context,
    required Medication medication,
    required List<MedicationIntake> history,
    MedicationSchedule? schedule,
    String? userName,
    String? userEmail,
  }) async {
    try {
      final pdfBytes = await generatePdfDocument(
        medication: medication,
        history: history,
        schedule: schedule,
        userName: userName,
        userEmail: userEmail,
      );

      final filename = '${medication.name.replaceAll(' ', '_')}_Medical_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      await Printing.layoutPdf(
        name: filename,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (context.mounted) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          material.SnackBar(
            content: material.Text('Failed to generate PDF report: $e'),
            backgroundColor: material.Colors.red,
          ),
        );
      }
    }
  }

  /// Generates the raw PDF bytes
  static Future<Uint8List> generatePdfDocument({
    required Medication medication,
    required List<MedicationIntake> history,
    MedicationSchedule? schedule,
    String? userName,
    String? userEmail,
  }) async {
    final analytics = MedicationAnalyticsService.computeAnalytics(
      medication: medication,
      history: history,
      schedule: schedule,
    );

    final pdf = pw.Document(
      title: '${medication.name} - Medication Adherence & Medical History Report',
      author: 'MedDay Flow',
    );

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontSemiBold = await PdfGoogleFonts.openSansSemiBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    // Primary clinical colors
    const primaryColor = PdfColor.fromInt(0xFF1E3A8A); // Deep Navy
    const accentColor = PdfColor.fromInt(0xFF2563EB); // Royal Blue
    const greenColor = PdfColor.fromInt(0xFF059669); // Emerald Green
    const orangeColor = PdfColor.fromInt(0xFFD97706); // Amber
    const redColor = PdfColor.fromInt(0xFFDC2626); // Crimson Red
    const lightGrey = PdfColor.fromInt(0xFFF1F5F9); // Slate 100
    const borderGrey = PdfColor.fromInt(0xFFE2E8F0); // Slate 200

    final sortedHistory = List<MedicationIntake>.from(history)
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

    // Page 1: Clinical Header, Prescription Specs & Top Analytics Dashboard
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
        ),
        footer: (pw.Context ctx) => _buildFooter(ctx, fontRegular),
        build: (pw.Context ctx) {
          return [
            // 1. Clinical Document Header
            _buildReportHeader(
              userName: userName,
              userEmail: userEmail,
              fontBold: fontBold,
              fontSemiBold: fontSemiBold,
              fontRegular: fontRegular,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
            pw.SizedBox(height: 16),

            // 2. Medication Prescription & Specifications Card
            _buildMedicationProfileCard(
              medication: medication,
              schedule: schedule,
              primaryColor: primaryColor,
              borderGrey: borderGrey,
              lightGrey: lightGrey,
              fontBold: fontBold,
              fontSemiBold: fontSemiBold,
            ),
            pw.SizedBox(height: 18),

            // 3. TOP ANALYTICS GRAPHS & KPIS SECTION
            _buildAnalyticsSectionTitle(fontBold: fontBold, primaryColor: primaryColor),
            pw.SizedBox(height: 10),

            _buildKpiCardsRow(
              analytics: analytics,
              medication: medication,
              greenColor: greenColor,
              accentColor: accentColor,
              orangeColor: orangeColor,
              redColor: redColor,
              lightGrey: lightGrey,
              borderGrey: borderGrey,
              fontBold: fontBold,
              fontSemiBold: fontSemiBold,
            ),
            pw.SizedBox(height: 16),

            // Visual Analytics Charts Row: Status Donut Chart & Day-of-Week Bar Chart
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: _buildStatusBreakdownChart(
                    analytics: analytics,
                    greenColor: greenColor,
                    orangeColor: orangeColor,
                    redColor: redColor,
                    accentColor: accentColor,
                    borderGrey: borderGrey,
                    lightGrey: lightGrey,
                    fontBold: fontBold,
                    fontSemiBold: fontSemiBold,
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  flex: 6,
                  child: _buildDayOfWeekChart(
                    analytics: analytics,
                    accentColor: accentColor,
                    borderGrey: borderGrey,
                    lightGrey: lightGrey,
                    fontBold: fontBold,
                    fontSemiBold: fontSemiBold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Punctuality & Circadian Window Row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildPunctualityCard(
                    analytics: analytics,
                    accentColor: accentColor,
                    greenColor: greenColor,
                    orangeColor: orangeColor,
                    borderGrey: borderGrey,
                    lightGrey: lightGrey,
                    fontBold: fontBold,
                    fontSemiBold: fontSemiBold,
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: _buildTimeOfDayPerformanceCard(
                    analytics: analytics,
                    primaryColor: primaryColor,
                    accentColor: accentColor,
                    borderGrey: borderGrey,
                    lightGrey: lightGrey,
                    fontBold: fontBold,
                    fontSemiBold: fontSemiBold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // 4. MEDICAL INTAKE HISTORY TABLE
            pw.Text(
              'Complete Medical Intake History Log',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 15,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Chronological audit trail of all recorded and scheduled medication intake events.',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 10),

            _buildHistoryTable(
              history: sortedHistory,
              medication: medication,
              fontBold: fontBold,
              fontRegular: fontRegular,
              greenColor: greenColor,
              orangeColor: orangeColor,
              redColor: redColor,
              primaryColor: primaryColor,
              borderGrey: borderGrey,
              lightGrey: lightGrey,
            ),
            pw.SizedBox(height: 20),

            // 5. Clinical Sign-off & Disclaimer Block
            _buildClinicalSignOffBlock(
              fontBold: fontBold,
              fontRegular: fontRegular,
              primaryColor: primaryColor,
              borderGrey: borderGrey,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // -------------------------------------------------------------
  // HEADER
  // -------------------------------------------------------------
  static pw.Widget _buildReportHeader({
    required String? userName,
    required String? userEmail,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
    required pw.Font fontRegular,
    required PdfColor primaryColor,
    required PdfColor accentColor,
  }) {
    final nowFormatted = DateFormat('MMMM d, yyyy | h:mm a').format(DateTime.now());

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 24,
                    height: 24,
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'M',
                        style: pw.TextStyle(
                          font: fontBold,
                          color: PdfColors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'MEDDAY FLOW',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: primaryColor,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Clinical Medication Adherence & Intake Telemetry Report',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PATIENT: ${userName ?? "Individual User"}',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: primaryColor,
                ),
              ),
              if (userEmail != null && userEmail.isNotEmpty)
                pw.Text(
                  userEmail,
                  style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey600),
                ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: $nowFormatted',
                style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MEDICATION PROFILE CARD
  // -------------------------------------------------------------
  static pw.Widget _buildMedicationProfileCard({
    required Medication medication,
    required MedicationSchedule? schedule,
    required PdfColor primaryColor,
    required PdfColor borderGrey,
    required PdfColor lightGrey,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: lightGrey,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderGrey),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  medication.name.toUpperCase(),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 14,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 3),
                if (medication.formula != null && medication.formula!.isNotEmpty)
                  pw.Text(
                    'Active Formula: ${medication.formula}',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 9.5, color: PdfColors.grey800),
                  ),
                if (medication.medicationClass != null && medication.medicationClass!.isNotEmpty)
                  pw.Text(
                    'Therapeutic Class: ${medication.medicationClass}',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 9.5, color: PdfColors.blue800),
                  ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Strength: ${medication.dosage} ${medication.unit.name}',
                  style: pw.TextStyle(font: fontBold, fontSize: 10, color: primaryColor),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Form Factor: ${medication.shape.toUpperCase()}',
                  style: pw.TextStyle(font: fontSemiBold, fontSize: 9, color: PdfColors.grey700),
                ),
                if (schedule != null)
                  pw.Text(
                    'Frequency: ${schedule.frequency.name.toUpperCase()}',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 9, color: PdfColors.grey700),
                  ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (schedule != null && schedule.timesPerDay.isNotEmpty)
                  pw.Text(
                    'Dosing Times: ${schedule.timesPerDay.map((t) => DateFormat('h:mm a').format(DateTime(2022, 1, 1, t.hour, t.minute))).join(', ')}',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 9, color: PdfColors.grey800),
                  ),
                if (schedule?.instructions != null && schedule!.instructions!.isNotEmpty)
                  pw.Text(
                    'Instructions: ${schedule.instructions}',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 9, color: PdfColors.blueGrey700),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TITLE
  // -------------------------------------------------------------
  static pw.Widget _buildAnalyticsSectionTitle({
    required pw.Font fontBold,
    required PdfColor primaryColor,
  }) {
    return pw.Row(
      children: [
        pw.Text(
          'Therapeutic Adherence & Telemetry Analytics',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 13,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // KPI SCORECARDS
  // -------------------------------------------------------------
  static pw.Widget _buildKpiCardsRow({
    required MedicationAnalyticsData analytics,
    required Medication medication,
    required PdfColor greenColor,
    required PdfColor accentColor,
    required PdfColor orangeColor,
    required PdfColor redColor,
    required PdfColor lightGrey,
    required PdfColor borderGrey,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    final adherencePercent = '${(analytics.adherenceRate * 100).toInt()}%';

    return pw.Row(
      children: [
        _buildKpiCard(
          title: 'ADHERENCE',
          value: adherencePercent,
          color: analytics.adherenceRate >= 0.8 ? greenColor : (analytics.adherenceRate >= 0.6 ? orangeColor : redColor),
          lightGrey: lightGrey,
          borderGrey: borderGrey,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'ON-TIME RATE',
          value: '${(analytics.onTimePercentage * 100).toInt()}%',
          color: greenColor,
          lightGrey: lightGrey,
          borderGrey: borderGrey,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'ACTIVE STREAK',
          value: '${analytics.currentStreakDays} Days',
          color: accentColor,
          lightGrey: lightGrey,
          borderGrey: borderGrey,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'TOTAL CONSUMED',
          value: '${analytics.totalDosageConsumed.toStringAsFixed(analytics.totalDosageConsumed % 1 == 0 ? 0 : 1)} ${medication.unit.name}',
          color: PdfColors.blueGrey800,
          lightGrey: lightGrey,
          borderGrey: borderGrey,
          fontBold: fontBold,
          fontSemiBold: fontSemiBold,
        ),
      ],
    );
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required PdfColor color,
    required PdfColor lightGrey,
    required PdfColor borderGrey,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: lightGrey,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: borderGrey),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                font: fontSemiBold,
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STATUS DONUT / DISTRIBUTION GRAPH
  // -------------------------------------------------------------
  static pw.Widget _buildStatusBreakdownChart({
    required MedicationAnalyticsData analytics,
    required PdfColor greenColor,
    required PdfColor orangeColor,
    required PdfColor redColor,
    required PdfColor accentColor,
    required PdfColor borderGrey,
    required PdfColor lightGrey,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    final total = analytics.totalScheduled;
    final takenPct = total > 0 ? (analytics.takenCount / total) : 0.0;
    final skippedPct = total > 0 ? (analytics.skippedCount / total) : 0.0;
    final missedPct = total > 0 ? (analytics.missedCount / total) : 0.0;
    final pendingPct = total > 0 ? (analytics.pendingCount / total) : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderGrey),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Intake Status Distribution',
            style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 8),

          // Horizontal segmented progress bar
          pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Container(
              height: 12,
              color: PdfColors.grey200,
              child: pw.Row(
                children: [
                  if (takenPct > 0)
                    pw.Expanded(
                      flex: (takenPct * 1000).toInt(),
                      child: pw.Container(color: greenColor),
                    ),
                  if (skippedPct > 0)
                    pw.Expanded(
                      flex: (skippedPct * 1000).toInt(),
                      child: pw.Container(color: orangeColor),
                    ),
                  if (missedPct > 0)
                    pw.Expanded(
                      flex: (missedPct * 1000).toInt(),
                      child: pw.Container(color: redColor),
                    ),
                  if (pendingPct > 0)
                    pw.Expanded(
                      flex: (pendingPct * 1000).toInt(),
                      child: pw.Container(color: accentColor),
                    ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 8),

          // Legend
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Taken', '${analytics.takenCount} (${(takenPct * 100).toInt()}%)', greenColor, fontSemiBold),
              _buildLegendItem('Skipped', '${analytics.skippedCount} (${(skippedPct * 100).toInt()}%)', orangeColor, fontSemiBold),
              _buildLegendItem('Missed', '${analytics.missedCount} (${(missedPct * 100).toInt()}%)', redColor, fontSemiBold),
              if (analytics.pendingCount > 0)
                _buildLegendItem('Pending', '${analytics.pendingCount}', accentColor, fontSemiBold),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLegendItem(String label, String value, PdfColor color, pw.Font fontSemiBold) {
    return pw.Row(
      children: [
        pw.Container(width: 8, height: 8, color: color),
        pw.SizedBox(width: 4),
        pw.Text(
          '$label: $value',
          style: pw.TextStyle(font: fontSemiBold, fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // DAY OF WEEK DISTRIBUTION BAR CHART
  // -------------------------------------------------------------
  static pw.Widget _buildDayOfWeekChart({
    required MedicationAnalyticsData analytics,
    required PdfColor accentColor,
    required PdfColor borderGrey,
    required PdfColor lightGrey,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderGrey),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Day-of-Week Adherence Consistency',
            style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 8),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: analytics.dayOfWeekStats.map((d) {
              final rate = d.adherenceRate;
              final barHeight = 28.0 * (rate == 0 && d.totalScheduled > 0 ? 0.08 : rate);

              return pw.Column(
                children: [
                  pw.Text(
                    d.totalScheduled > 0 ? '${(rate * 100).toInt()}%' : '-',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 6.5, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    width: 14,
                    height: 28,
                    alignment: pw.Alignment.bottomCenter,
                    child: pw.Container(
                      height: barHeight > 0 ? barHeight : 2,
                      width: 14,
                      decoration: pw.BoxDecoration(
                        color: d.totalScheduled == 0
                            ? PdfColors.grey300
                            : (rate >= 0.8 ? const PdfColor.fromInt(0xFF059669) : accentColor),
                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2)),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    d.dayName,
                    style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.grey800),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PUNCTUALITY CARD
  // -------------------------------------------------------------
  static pw.Widget _buildPunctualityCard({
    required MedicationAnalyticsData analytics,
    required PdfColor accentColor,
    required PdfColor greenColor,
    required PdfColor orangeColor,
    required PdfColor borderGrey,
    required PdfColor lightGrey,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderGrey),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Timing Punctuality & Variance',
            style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('On-time (±30m):', style: pw.TextStyle(font: fontSemiBold, fontSize: 8.5)),
              pw.Text('${analytics.onTimeCount} doses', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: greenColor)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Delayed (30-90m):', style: pw.TextStyle(font: fontSemiBold, fontSize: 8.5)),
              pw.Text('${analytics.delayedCount} doses', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: orangeColor)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Significantly Late (>90m):', style: pw.TextStyle(font: fontSemiBold, fontSize: 8.5)),
              pw.Text('${analytics.significantlyDelayedCount} doses', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.red700)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Average Timing Deviation:', style: pw.TextStyle(font: fontSemiBold, fontSize: 8.5)),
              pw.Text('${analytics.averageDelayMinutes.toInt()} mins', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: accentColor)),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TIME OF DAY PERFORMANCE CARD
  // -------------------------------------------------------------
  static pw.Widget _buildTimeOfDayPerformanceCard({
    required MedicationAnalyticsData analytics,
    required PdfColor primaryColor,
    required PdfColor accentColor,
    required PdfColor borderGrey,
    required PdfColor lightGrey,
    required pw.Font fontBold,
    required pw.Font fontSemiBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderGrey),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Circadian Window Adherence',
            style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),
          ...analytics.timeOfDayStats.map((slot) {
            final pct = slot.totalScheduled > 0 ? (slot.takenCount / slot.totalScheduled) : 0.0;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${slot.title} (${slot.timeRange}):',
                    style: pw.TextStyle(font: fontSemiBold, fontSize: 8),
                  ),
                  pw.Text(
                    slot.totalScheduled > 0 ? '${slot.takenCount}/${slot.totalScheduled} (${(pct * 100).toInt()}%)' : 'None',
                    style: pw.TextStyle(font: fontBold, fontSize: 8, color: slot.totalScheduled > 0 ? primaryColor : PdfColors.grey500),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MEDICAL HISTORY TABLE
  // -------------------------------------------------------------
  static pw.Widget _buildHistoryTable({
    required List<MedicationIntake> history,
    required Medication medication,
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required PdfColor greenColor,
    required PdfColor orangeColor,
    required PdfColor redColor,
    required PdfColor primaryColor,
    required PdfColor borderGrey,
    required PdfColor lightGrey,
  }) {
    if (history.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: borderGrey),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Center(
          child: pw.Text(
            'No logged intake events found in medical history.',
            style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey600),
          ),
        ),
      );
    }

    final headers = [
      'Date',
      'Scheduled',
      'Logged Time',
      'Status',
      'Variance',
      'Dose Taken',
      'Notes & Clinical Remarks',
    ];

    final rows = history.map((intake) {
      final dateStr = DateFormat('MMM d, yyyy').format(intake.logicalDate);
      final scheduledStr = DateFormat('h:mm a').format(intake.scheduledTime);
      final loggedStr = intake.actualTime != null ? DateFormat('h:mm a').format(intake.actualTime!) : '-';

      String statusStr = 'Pending';
      if (intake.status == IntakeStatus.taken) {
        statusStr = 'TAKEN';
      } else if (intake.status == IntakeStatus.skipped) {
        statusStr = 'SKIPPED';
      } else if (intake.status == IntakeStatus.missed) {
        statusStr = 'MISSED';
      }

      String varianceStr = '-';
      if (intake.actualTime != null && intake.status == IntakeStatus.taken) {
        final diff = intake.actualTime!.difference(intake.scheduledTime).inMinutes;
        if (diff.abs() <= 15) {
          varianceStr = 'On-time';
        } else if (diff > 15) {
          varianceStr = '+$diff min';
        } else {
          varianceStr = '$diff min';
        }
      }

      final doseStr = intake.dosageTaken != null
          ? '${intake.dosageTaken} ${medication.unit.name}'
          : (intake.status == IntakeStatus.taken ? '${medication.dosage} ${medication.unit.name}' : '-');

      final notesStr = intake.notes ?? '-';

      return [
        dateStr,
        scheduledStr,
        loggedStr,
        statusStr,
        varianceStr,
        doseStr,
        notesStr,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A8A)),
      cellStyle: pw.TextStyle(font: fontRegular, fontSize: 7.5),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
    );
  }

  // -------------------------------------------------------------
  // CLINICAL SIGN-OFF
  // -------------------------------------------------------------
  static pw.Widget _buildClinicalSignOffBlock({
    required pw.Font fontBold,
    required pw.Font fontRegular,
    required PdfColor primaryColor,
    required PdfColor borderGrey,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderGrey),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Clinical Attestation & Notes',
            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: primaryColor),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This report was compiled and verified using MedDay Flow\'s chronotherapy event logs. '
            'Information provided is intended for patient review and healthcare provider consultation. '
            'Changes to dosing regimens should only be made under qualified medical supervision.',
            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 2),
                  pw.Text('Healthcare Provider Signature', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 120, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 2),
                  pw.Text('Date', style: pw.TextStyle(font: fontRegular, fontSize: 7.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // FOOTER
  // -------------------------------------------------------------
  static pw.Widget _buildFooter(pw.Context ctx, pw.Font fontRegular) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MedDay Flow | Patient Health & Circadian Medication System',
            style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
