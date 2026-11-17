import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:medday_flow/services/native_preferences_service.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';

/// Result object for Android Health Connect synchronization operations.
class HealthSyncResult {
  final bool success;
  final int syncedCount;
  final String? errorMessage;
  final bool skipped;

  const HealthSyncResult({
    required this.success,
    this.syncedCount = 0,
    this.errorMessage,
    this.skipped = false,
  });

  bool get isSuccess => success;
  int get itemsSynced => syncedCount;
  String get message {
    if (errorMessage != null) return errorMessage!;
    if (skipped) return 'Health Connect sync skipped on this platform';
    if (syncedCount == 0) return 'No taken medication doses to sync';
    return 'Successfully synced $syncedCount medication dose(s) to Health Connect';
  }
}

/// Android Health Connect synchronization service.
///
/// Targets the Android Health Connect API (`com.google.android.apps.healthdata`)
/// exclusively on Android (`Platform.isAndroid`). All legacy Google Fit REST API
/// and iOS HealthKit pathways have been removed. On iOS and other platforms,
/// execution is gracefully skipped.
class HealthSyncService {
  static const String _healthStorageKey = 'daily_planner_health_connect_synced_records';
  static const String _healthPermissionKey = 'daily_planner_health_connect_permission_granted';
  static const String healthConnectPackageName = 'com.google.android.apps.healthdata';

  /// Android-only native Health Connect channel (implemented in MainActivity.kt).
  static const MethodChannel _channel = MethodChannel('daily_planner/native_health');

  final NativePreferencesService? _customPrefsService;

  HealthSyncService({NativePreferencesService? prefsService})
      : _customPrefsService = prefsService;

  /// Health Connect is strictly supported on Android only.
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

  /// Converts a [MedicationIntake] to an Android Health Connect record payload
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
      'healthConnectPackage': healthConnectPackageName,
      'metadata': {
        'source': 'MedDay Flow',
        'recordingMethod': 'RECORDING_METHOD_MANUAL_ENTRY',
        'frequency': intake.schedule.frequency.name,
        'instructions': intake.schedule.instructions ?? '',
      },
    };
  }

  Future<bool> checkHealthPlatformAvailability() async {
    if (!isSupported) return false;
    return await _invoke<bool>('checkAvailability') ?? true;
  }

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
    if (!isSupported) return;
    await _invoke<void>('revokePermissions');
    final prefs = await _getPrefs();
    await prefs.setBool(_healthPermissionKey, false);
  }

  /// Synchronize taken medication intakes to Android Health Connect.
  ///
  /// Gracefully skips execution on iOS and non-Android platforms.
  Future<HealthSyncResult> syncMedications([
    List<MedicationIntake> intakes = const [],
  ]) async {
    if (!isSupported) {
      debugPrint('HealthSyncService: Skipping Health Connect sync on non-Android platform.');
      return const HealthSyncResult(
        success: true,
        syncedCount: 0,
        skipped: true,
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

      final List<Map<String, dynamic>> batchPayloads = [];
      for (final intake in takenIntakes) {
        final record = intakeToHealthRecord(intake);
        recordsMap[intake.intakeId] = record;
        batchPayloads.add(record);
      }

      // Prefer single batched Health Connect write IPC call, falling back to per-record write
      final batchSaved = await _invoke<bool>(
        'saveMedicationRecordsBatch',
        {'records': batchPayloads},
      );
      if (batchSaved != true) {
        for (final record in batchPayloads) {
          await _invoke<bool>('saveMedicationRecord', record);
        }
      }

      await prefs.setString(_healthStorageKey, json.encode(recordsMap.values.toList()));
      return HealthSyncResult(success: true, syncedCount: batchPayloads.length);
    } catch (e) {
      debugPrint('Health Connect sync error: $e');
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
      debugPrint('Error retrieving synced Health Connect records: $e');
      return [];
    }
  }

  Future<void> clearSyncedRecords() async {
    if (!isSupported) return;
    final prefs = await _getPrefs();
    await prefs.setString(_healthStorageKey, '[]');
  }
}
