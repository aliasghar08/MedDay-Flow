import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:medday_flow/services/native_preferences_service.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';

/// Result object for Health Platform synchronization operations.
class HealthSyncResult {
  final bool success;
  final int syncedCount;
  final String? errorMessage;

  const HealthSyncResult({
    required this.success,
    this.syncedCount = 0,
    this.errorMessage,
  });

  bool get isSuccess => success;
  int get itemsSynced => syncedCount;
  String get message =>
      errorMessage ??
      (syncedCount == 0
          ? 'No taken medication doses to sync'
          : 'Successfully synced $syncedCount medication dose(s) to Google Fit');
}

/// Health platform synchronization (Android Google Fit / Health Connect ONLY).
///
/// There is no Apple Health / HealthKit integration on iOS. On every
/// platform other than Android, all methods are inert no-ops.
class HealthSyncService {
  static const String _healthStorageKey = 'daily_planner_health_synced_records';
  static const String _healthPermissionKey = 'daily_planner_health_permission_granted';

  /// Android-only native channel (implemented in MainActivity.kt).
  static const MethodChannel _channel = MethodChannel('daily_planner/native_health');

  final NativePreferencesService? _customPrefsService;

  HealthSyncService({NativePreferencesService? prefsService})
      : _customPrefsService = prefsService;

  /// Health sync is only supported on Android.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<NativePreferencesService> _getPrefs() async {
    return _customPrefsService ?? await NativePreferencesService.getInstance();
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('HealthSyncService.$method error: $e');
      return null;
    }
  }

  /// Converts a [MedicationIntake] to a Health Connect record payload
  Map<String, dynamic> intakeToHealthRecord(MedicationIntake intake) {
    final med = intake.schedule.medication;

    return {
      'recordId': 'health_${intake.intakeId}',
      'intakeId': intake.intakeId,
      'medicationName': med.name,
      'dosage': intake.dosageTaken ?? med.dosage,
      'dosageUnit': med.unit.name,
      'status': intake.status.name,
      'scheduledTime': intake.scheduledTime.toUtc().toIso8601String(),
      'actualTime': intake.actualTime?.toUtc().toIso8601String(),
      'logicalDate': intake.logicalDate.toIso8601String(),
      'syncedAt': DateTime.now().toUtc().toIso8601String(),
      'platform': 'Health Connect',
      'metadata': {
        'source': 'MedDay Flow',
        'frequency': intake.schedule.frequency.name,
        'instructions': intake.schedule.instructions ?? '',
      },
    };
  }

  Future<bool> checkHealthPlatformAvailability() async => isSupported;

  Future<bool> isHealthPermissionGranted() async {
    if (!isSupported) return false;
    final prefs = await _getPrefs();
    if (!(prefs.getBool(_healthPermissionKey) ?? false)) return false;
    return await _invoke<bool>('checkPermissions') ?? false;
  }

  Future<bool> requestHealthPermissions() async {
    if (!isSupported) return false;
    final granted = await _invoke<bool>('requestPermissions') ?? false;
    final prefs = await _getPrefs();
    await prefs.setBool(_healthPermissionKey, granted);
    return granted;
  }

  Future<void> revokeHealthPermissions() async {
    await _invoke<void>('revokePermissions');
    final prefs = await _getPrefs();
    await prefs.setBool(_healthPermissionKey, false);
  }

  /// Synchronize taken medication intakes to Google Fit / Health Connect.
  Future<HealthSyncResult> syncMedications([
    List<MedicationIntake> intakes = const [],
  ]) async {
    if (!isSupported) {
      return const HealthSyncResult(
        success: false,
        errorMessage: 'Health sync is not available on this platform.',
      );
    }

    final takenIntakes = intakes.where((i) => i.status == IntakeStatus.taken).toList();
    if (takenIntakes.isEmpty) {
      return const HealthSyncResult(success: true, syncedCount: 0);
    }

    if (!await isHealthPermissionGranted()) {
      return const HealthSyncResult(
        success: false,
        errorMessage: 'Health Connect permissions not granted. Please enable in settings.',
      );
    }

    try {
      final prefs = await _getPrefs();
      final List<dynamic> rawList =
          json.decode(prefs.getString(_healthStorageKey) ?? '[]') as List<dynamic>? ?? [];
      final Map<String, Map<String, dynamic>> recordsMap = {
        for (var item in rawList)
          (item as Map<String, dynamic>)['intakeId'] as String: item,
      };

      int count = 0;
      for (final intake in takenIntakes) {
        final record = intakeToHealthRecord(intake);
        recordsMap[intake.intakeId] = record;
        await _invoke<bool>('saveMedicationRecord', record);
        count++;
      }

      await prefs.setString(_healthStorageKey, json.encode(recordsMap.values.toList()));
      return HealthSyncResult(success: true, syncedCount: count);
    } catch (e) {
      debugPrint('Health sync error: $e');
      return HealthSyncResult(success: false, errorMessage: e.toString());
    }
  }

  /// Alias for syncMedications for backward compatibility
  Future<HealthSyncResult> syncMedicationIntakes({
    required List<MedicationIntake> intakes,
  }) async {
    return syncMedications(intakes);
  }

  Future<List<Map<String, dynamic>>> getSyncedHealthRecords() async {
    if (!isSupported) return [];
    try {
      final list = await _invoke<List<dynamic>>('fetchMedicationRecords');
      if (list != null && list.isNotEmpty) {
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      final prefs = await _getPrefs();
      final List<dynamic> rawList =
          json.decode(prefs.getString(_healthStorageKey) ?? '[]') as List<dynamic>? ?? [];
      return rawList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error retrieving synced health records: $e');
      return [];
    }
  }

  Future<void> clearSyncedRecords() async {
    final prefs = await _getPrefs();
    await prefs.setString(_healthStorageKey, '[]');
  }
}
