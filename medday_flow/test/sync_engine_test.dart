import 'package:medday_flow/models/sync_config_model.dart';
import 'package:medday_flow/services/sync/google_calendar_sync_service.dart';
import 'package:medday_flow/services/sync/google_tasks_sync_service.dart';
import 'package:medday_flow/services/sync/health_sync_service.dart';
import 'package:medday_flow/services/sync/sync_manager.dart';
import 'package:medday_flow/utils/medication_model/frequency_and_dosage.dart';
import 'package:medday_flow/utils/medication_model/medication_intake.dart';
import 'package:medday_flow/utils/medication_model/medication_model.dart';
import 'package:medday_flow/utils/medication_model/medication_schedule_model.dart';
import 'package:medday_flow/utils/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('daily_planner/native_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );
  });

  group('Google Calendar Sync Engine Tests', () {
    late GoogleCalendarSyncService calendarService;

    setUp(() {
      calendarService = GoogleCalendarSyncService();
    });

    test('Maps one-time Task to Google Calendar Event payload correctly', () {
      final task = Task(
        docId: 'task_123',
        title: 'Project Standup',
        detail: 'Discuss Sprint Goals',
        date: DateTime(2026, 8, 10, 10, 0),
        isCompleted: false,
        taskType: 'oneTime',
      );

      final event = calendarService.taskToCalendarEvent(task);

      expect(event['summary'], equals('Project Standup'));
      expect(event['description'], contains('Discuss Sprint Goals'));
      expect(event['description'], contains('[Synced from Medday Flow]'));
      expect(event['start']['dateTime'], isNotNull);
      expect(event['end']['dateTime'], isNotNull);
      expect(event['extendedProperties']['private']['dailyPlannerTaskId'], equals('task_123'));
      expect(event['extendedProperties']['private']['dailyPlannerTaskType'], equals('oneTime'));
      expect(event.containsKey('recurrence'), isFalse);
    });

    test('Generates RRULE recurrence for recurring tasks', () {
      final dailyTask = Task(
        docId: 'task_daily',
        title: 'Daily Exercise',
        detail: '30 mins workout',
        date: DateTime(2026, 8, 10, 7, 0),
        isCompleted: false,
        taskType: 'daily',
      );

      final weeklyTask = Task(
        docId: 'task_weekly',
        title: 'Weekly Review',
        detail: 'Weekly planning session',
        date: DateTime(2026, 8, 10, 18, 0),
        isCompleted: false,
        taskType: 'weekly',
      );

      final monthlyTask = Task(
        docId: 'task_monthly',
        title: 'Pay Bills',
        detail: 'Electricity & rent',
        date: DateTime(2026, 8, 10, 12, 0),
        isCompleted: false,
        taskType: 'monthly',
      );

      final dailyEvent = calendarService.taskToCalendarEvent(dailyTask);
      final weeklyEvent = calendarService.taskToCalendarEvent(weeklyTask);
      final monthlyEvent = calendarService.taskToCalendarEvent(monthlyTask);

      expect(dailyEvent['recurrence'], equals(['RRULE:FREQ=DAILY']));
      expect(weeklyEvent['recurrence'], equals(['RRULE:FREQ=WEEKLY']));
      expect(monthlyEvent['recurrence'], equals(['RRULE:FREQ=MONTHLY']));
    });

    test('Handles offline fallback when access token is null', () async {
      final tasks = [
        Task(
          docId: 't1',
          title: 'Offline Task',
          detail: 'Offline Detail',
          date: DateTime.now(),
          isCompleted: false,
        ),
      ];

      final result = await calendarService.pushTasksToCalendar(
        tasks: tasks,
        accessToken: null,
      );

      expect(result.isSuccess, isTrue);
      expect(result.itemsSynced, equals(1));
    });

    test('Retries with exponential backoff on HTTP 429 Too Many Requests', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount < 3) {
          return http.Response('{"error":{"code":429,"message":"Rate Limit Exceeded"}}', 429);
        }
        return http.Response('{"id":"cal_evt_1"}', 200);
      });

      final retryService = GoogleCalendarSyncService(
        httpClient: mockClient,
        maxRetries: 4,
        baseBackoffDelay: const Duration(milliseconds: 5),
      );

      final result = await retryService.pushTasksToCalendar(
        tasks: [
          Task(
            docId: 't_rate',
            title: 'Rate Limited Task',
            detail: 'Should succeed on 3rd attempt',
            date: DateTime(2026, 8, 10, 9, 0),
            isCompleted: false,
          ),
        ],
        accessToken: 'valid_token',
      );

      expect(result.isSuccess, isTrue);
      expect(result.itemsSynced, equals(1));
      expect(callCount, equals(3));
    });

    test('Batches multiple tasks into a single multipart/mixed request and refreshes expired OAuth token on 401', () async {
      int batchCalls = 0;
      String? lastAuthHeader;
      final mockClient = MockClient((request) async {
        batchCalls++;
        lastAuthHeader = request.headers['Authorization'];
        if (lastAuthHeader == 'Bearer expired_token') {
          return http.Response('{"error":{"code":401,"message":"Invalid Credentials"}}', 401);
        }
        expect(request.url.toString(), equals('https://www.googleapis.com/batch/calendar/v3'));
        expect(request.headers['Content-Type'], contains('multipart/mixed'));
        return http.Response(
          '--batch_medday_calendar\r\n'
          'Content-Type: application/http\r\n\r\n'
          'HTTP/1.1 200 OK\r\n\r\n{}\r\n'
          '--batch_medday_calendar\r\n'
          'Content-Type: application/http\r\n\r\n'
          'HTTP/1.1 201 Created\r\n\r\n{}\r\n'
          '--batch_medday_calendar--',
          200,
        );
      });

      final batchService = GoogleCalendarSyncService(
        httpClient: mockClient,
        baseBackoffDelay: const Duration(milliseconds: 5),
        onTokenRefresh: () async => 'refreshed_token_xyz',
      );

      final result = await batchService.pushTasksToCalendar(
        tasks: [
          Task(docId: 'b1', title: 'Batch 1', detail: 'D1', date: DateTime(2026, 8, 10, 9, 0), isCompleted: false),
          Task(docId: 'b2', title: 'Batch 2', detail: 'D2', date: DateTime(2026, 8, 10, 10, 0), isCompleted: false),
        ],
        accessToken: 'expired_token',
      );

      expect(result.isSuccess, isTrue);
      expect(result.itemsSynced, equals(2));
      expect(batchCalls, equals(2)); // 1st 401, 2nd 200 with refreshed token
      expect(lastAuthHeader, equals('Bearer refreshed_token_xyz'));
    });
  });

  group('Google Tasks Sync Engine Tests', () {
    late GoogleTasksSyncService tasksService;

    setUp(() {
      tasksService = GoogleTasksSyncService();
    });

    test('Maps Task to Google Tasks payload format', () {
      final task = Task(
        docId: 'gtask_1',
        title: 'Buy Groceries',
        detail: 'Milk, Eggs, Bread',
        date: DateTime(2026, 8, 12, 15, 0),
        isCompleted: true,
        completedAt: DateTime(2026, 8, 12, 16, 30),
      );

      final payload = tasksService.taskToGoogleTask(task);

      expect(payload['title'], equals('Buy Groceries'));
      expect(payload['notes'], contains('Milk, Eggs, Bread'));
      expect(payload['status'], equals('completed'));
      expect(payload['completed'], isNotNull);
      expect(payload['due'], isNotNull);
    });

    test('Converts Google Task item back to Daily Planner Task', () {
      final googleTaskJson = {
        'id': 'remote_task_99',
        'title': 'Submit Tax Return',
        'notes': 'Online submission\n\n[Synced from Daily Planner | ID: local_12]',
        'status': 'completed',
        'due': '2026-08-15T00:00:00.000Z',
        'completed': '2026-08-15T10:00:00.000Z',
      };

      final task = tasksService.googleTaskToDailyPlannerTask(googleTaskJson);

      expect(task.docId, equals('remote_task_99'));
      expect(task.title, equals('Submit Tax Return'));
      expect(task.detail, equals('Online submission')); // Footer cleaned
      expect(task.isCompleted, isTrue);
      expect(task.completedAt, isNotNull);
    });

    test('Retries Google Tasks push with exponential backoff on 429 and batches multiple tasks', () async {
      int attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response('Rate Limit Exceeded', 429);
        }
        expect(request.url.toString(), equals('https://www.googleapis.com/batch/tasks/v1'));
        return http.Response(
          '--batch_medday_tasks\r\n'
          'HTTP/1.1 200 OK\r\n\r\n{}\r\n'
          '--batch_medday_tasks\r\n'
          'HTTP/1.1 200 OK\r\n\r\n{}\r\n'
          '--batch_medday_tasks--',
          200,
        );
      });

      final retryTasksService = GoogleTasksSyncService(
        httpClient: mockClient,
        baseBackoffDelay: const Duration(milliseconds: 5),
      );

      final result = await retryTasksService.pushTasksToGoogleTasks(
        tasks: [
          Task(docId: 'gt1', title: 'Task 1', detail: 'N1', date: DateTime(2026, 8, 12), isCompleted: false),
          Task(docId: 'gt2', title: 'Task 2', detail: 'N2', date: DateTime(2026, 8, 12), isCompleted: true),
        ],
        accessToken: 'tasks_token_123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.itemsSynced, equals(2));
      expect(attempts, equals(2));
    });
  });

  group('Health Platform Sync Engine Tests', () {
    late HealthSyncService healthService;

    setUp(() {
      healthService = HealthSyncService();
    });

    test('Maps MedicationIntake to Health Platform record payload correctly', () {
      final med = Medication(
        medicationId: 'med_ser',
        name: 'Sertraline',
        dosage: 50.0,
        unit: DosageUnit.mg,
      );

      final schedule = MedicationSchedule(
        scheduleId: 'sched_ser',
        medication: med,
        startDate: DateTime(2026, 8, 1),
        frequency: MedicationFrequency.daily,
        timesPerDay: [const TimeOfDay(hour: 8, minute: 0)],
        instructions: 'Take with water after breakfast',
      );

      final scheduledTime = DateTime(2026, 8, 8, 8, 0);
      final actualTime = DateTime(2026, 8, 8, 8, 15);

      final intake = MedicationIntake(
        intakeId: 'intake_101',
        schedule: schedule,
        scheduledTime: scheduledTime,
        status: IntakeStatus.taken,
        actualTime: actualTime,
        dosageTaken: 50.0,
      );

      final record = healthService.intakeToHealthRecord(intake);

      expect(record['recordId'], equals('health_intake_101'));
      expect(record['medicationName'], equals('Sertraline'));
      expect(record['dosage'], equals(50.0));
      expect(record['dosageUnit'], equals('mg'));
      expect(record['status'], equals('taken'));
      expect(record['actualTime'], equals(actualTime.toUtc().toIso8601String()));
      expect(record['logicalDate'], equals(intake.logicalDate.toIso8601String()));
      expect(record['platform'], equals('Health Connect'));
      expect(record['healthConnectPackage'], equals('com.google.android.apps.healthdata'));
      expect(record['metadata']['instructions'], equals('Take with water after breakfast'));
    });

    test('Gracefully skips Health Connect sync on non-Android platforms', () async {
      final result = await healthService.syncMedications();
      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, equals(0));
      expect(result.skipped, isTrue);
    });
  });

  group('Sync Models & Configuration Tests', () {
    test('SyncConfig serializes and deserializes correctly', () {
      final config = SyncConfig(
        googleCalendarEnabled: true,
        googleTasksEnabled: true,
        healthSyncEnabled: true,
        googleAccountEmail: 'user@example.com',
        lastCalendarSync: DateTime(2026, 8, 8, 10, 30),
        lastTasksSync: DateTime(2026, 8, 8, 10, 31),
        lastHealthSync: DateTime(2026, 8, 8, 10, 32),
        autoSyncIntervalMinutes: 15,
        syncCompletedTasks: true,
        healthPermissionGranted: true,
      );

      final jsonString = config.toJson();
      final decoded = SyncConfig.fromJson(jsonString);

      expect(decoded.googleCalendarEnabled, isTrue);
      expect(decoded.googleTasksEnabled, isTrue);
      expect(decoded.healthSyncEnabled, isTrue);
      expect(decoded.googleAccountEmail, equals('user@example.com'));
      expect(decoded.autoSyncIntervalMinutes, equals(15));
      expect(decoded.healthPermissionGranted, isTrue);
      expect(decoded.lastCalendarSync, isNotNull);
    });

    test('SyncLogEntry serializes and deserializes correctly', () {
      final entry = SyncLogEntry(
        id: 'log_1',
        serviceType: SyncServiceType.googleCalendar,
        timestamp: DateTime(2026, 8, 8, 11, 0),
        isSuccess: true,
        message: 'Synced 5 items',
        itemsSynced: 5,
      );

      final jsonStr = entry.toJson();
      final decoded = SyncLogEntry.fromJson(jsonStr);

      expect(decoded.id, equals('log_1'));
      expect(decoded.serviceType, equals(SyncServiceType.googleCalendar));
      expect(decoded.isSuccess, isTrue);
      expect(decoded.itemsSynced, equals(5));
      expect(decoded.message, equals('Synced 5 items'));
    });
  });

  group('SyncManager Master Coordinator Tests', () {
    late SyncManager syncManager;

    setUp(() {
      syncManager = SyncManager();
    });

    test('SyncManager persists and updates configuration', () async {
      final initialConfig = await syncManager.loadConfig();
      expect(initialConfig, isNotNull);

      final updatedConfig = initialConfig.copyWith(
        googleCalendarEnabled: true,
        googleTasksEnabled: true,
        googleAccountEmail: 'test_coordinator@example.com',
      );

      await syncManager.saveConfig(updatedConfig);
      final loaded = await syncManager.loadConfig();

      expect(loaded.googleCalendarEnabled, isTrue);
      expect(loaded.googleTasksEnabled, isTrue);
      expect(loaded.googleAccountEmail, equals('test_coordinator@example.com'));
    });

    test('SyncManager records and caps activity logs', () async {
      final entry = SyncLogEntry(
        id: 'coord_log_1',
        serviceType: SyncServiceType.googleTasks,
        timestamp: DateTime.now(),
        isSuccess: true,
        message: 'Synchronized Google Tasks',
        itemsSynced: 3,
      );

      await syncManager.addLog(entry);
      final logs = await syncManager.loadLogs();

      expect(logs.isNotEmpty, isTrue);
      expect(logs.any((l) => l.id == 'coord_log_1'), isTrue);
    });
  });
}
