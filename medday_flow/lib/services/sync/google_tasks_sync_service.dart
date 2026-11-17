import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:medday_flow/services/native_google_sign_in.dart';
import 'package:medday_flow/services/sync/google_calendar_sync_service.dart';
import 'package:medday_flow/utils/catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service handling Google Tasks API v1 synchronization for Medday Flow tasks.
///
/// Includes:
/// - Exponential backoff with jitter for HTTP 429 (Too Many Requests) & 503 responses.
/// - Google Batch API (`multipart/mixed`) support to minimize payload overhead & latency.
/// - Automatic background OAuth token refresh on HTTP 401 (Unauthorized).
class GoogleTasksSyncService {
  static const String _tasksApiBase =
      'https://tasks.googleapis.com/tasks/v1/lists/@default/tasks';
  static const String _tasksBatchUrl =
      'https://www.googleapis.com/batch/tasks/v1';
  static const String _tasksRelativePath =
      '/tasks/v1/lists/@default/tasks';

  /// Maximum operations allowed in a single Google Tasks batch request.
  static const int maxBatchSize = 50;

  final http.Client _httpClient;
  final TokenRefreshCallback? _onTokenRefresh;
  final int maxRetries;
  final Duration baseBackoffDelay;
  final Random _random = Random();

  GoogleTasksSyncService({
    http.Client? httpClient,
    TokenRefreshCallback? onTokenRefresh,
    this.maxRetries = 4,
    this.baseBackoffDelay = const Duration(milliseconds: 500),
  })  : _httpClient = httpClient ?? http.Client(),
        _onTokenRefresh = onTokenRefresh;

  /// Executes an HTTP request with:
  /// 1. Automatic OAuth token refresh on HTTP 401 (once per request chain).
  /// 2. Exponential backoff with jitter on HTTP 429 (Too Many Requests) and 503.
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(String token) requestBuilder, {
    required String accessToken,
    TokenRefreshCallback? onTokenRefresh,
    ValueChanged<String>? onTokenUpdated,
  }) async {
    String currentToken = accessToken;
    bool hasAttemptedTokenRefresh = false;
    final refreshFn = onTokenRefresh ?? _onTokenRefresh ?? NativeGoogleSignIn.refreshAccessToken;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final response = await requestBuilder(currentToken);

      // Handle expired OAuth token (401 Unauthorized)
      if (response.statusCode == 401 && !hasAttemptedTokenRefresh) {
        hasAttemptedTokenRefresh = true;
        final refreshedToken = await refreshFn();
        if (refreshedToken != null &&
            refreshedToken.isNotEmpty &&
            refreshedToken != currentToken) {
          currentToken = refreshedToken;
          onTokenUpdated?.call(currentToken);
          final retryResponse = await requestBuilder(currentToken);
          if (retryResponse.statusCode != 429 && retryResponse.statusCode != 503) {
            return retryResponse;
          }
        } else {
          return response;
        }
      }

      // Return immediately if not rate-limited (429) or temporarily unavailable (503)
      if (response.statusCode != 429 && response.statusCode != 503) {
        return response;
      }

      if (attempt == maxRetries) {
        return response;
      }

      final delay = _computeBackoffDelay(attempt, response.headers['retry-after']);
      debugPrint(
        'GoogleTasksSyncService: HTTP ${response.statusCode} rate limit hit '
        '(attempt ${attempt + 1}/$maxRetries). Backing off for ${delay.inMilliseconds}ms.',
      );
      await Future<void>.delayed(delay);
    }

    return requestBuilder(currentToken);
  }

  Duration _computeBackoffDelay(int attempt, String? retryAfterHeader) {
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader.trim());
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds);
      }
    }
    final exponentialMs = baseBackoffDelay.inMilliseconds * (1 << attempt);
    final jitterMs = baseBackoffDelay.inMilliseconds > 0
        ? _random.nextInt(max(1, baseBackoffDelay.inMilliseconds ~/ 2))
        : 0;
    return Duration(milliseconds: exponentialMs + jitterMs);
  }

  /// Converts a Medday Flow [Task] to a Google Tasks JSON payload
  Map<String, dynamic> taskToGoogleTask(Task task) {
    final taskDate = task.date ?? task.createdAt;

    final payload = <String, dynamic>{
      'title': task.title,
      'notes': '${task.detail}\n\n[Synced from Medday Flow | ID: ${task.docId ?? "local"}]',
      'due': taskDate.toUtc().toIso8601String(),
      'status': task.isCompleted ? 'completed' : 'needsAction',
    };

    if (task.isCompleted && task.completedAt != null) {
      payload['completed'] = task.completedAt!.toUtc().toIso8601String();
    }

    return payload;
  }

  /// Converts a Google Task JSON map to a Medday Flow [Task]
  Task googleTaskToDailyPlannerTask(Map<String, dynamic> map) {
    final title = map['title'] as String? ?? 'Untitled Task';
    final notes = map['notes'] as String? ?? '';
    final isCompleted = (map['status'] as String? ?? 'needsAction') == 'completed';
    final dueStr = map['due'] as String?;
    final completedStr = map['completed'] as String?;

    DateTime? dueDate;
    if (dueStr != null) {
      dueDate = DateTime.tryParse(dueStr);
    }

    DateTime? completedAt;
    if (completedStr != null) {
      completedAt = DateTime.tryParse(completedStr);
    }

    // Clean notes by removing the sync footer if present
    final cleanDetail = notes
        .replaceAll(RegExp(r'\n\n\[Synced from (Daily Planner|Medday Flow).*\]'), '')
        .trim();

    return Task(
      docId: map['id'] as String?,
      title: title,
      detail: cleanDetail,
      date: dueDate ?? DateTime.now(),
      isCompleted: isCompleted,
      completedAt: completedAt,
      taskType: 'oneTime',
    );
  }

  /// Builds a `multipart/mixed` HTTP batch body for multiple Google Tasks insertions.
  String buildBatchPayload(List<Task> chunk, {String boundary = 'batch_medday_tasks'}) {
    final buffer = StringBuffer();
    for (int i = 0; i < chunk.length; i++) {
      final bodyJson = json.encode(taskToGoogleTask(chunk[i]));
      buffer.writeln('--$boundary');
      buffer.writeln('Content-Type: application/http');
      buffer.writeln('Content-ID: <item-$i>');
      buffer.writeln();
      buffer.writeln('POST $_tasksRelativePath HTTP/1.1');
      buffer.writeln('Content-Type: application/json; charset=utf-8');
      buffer.writeln();
      buffer.writeln(bodyJson);
    }
    buffer.write('--$boundary--');
    return buffer.toString();
  }

  /// Push tasks to Google Tasks using batched requests (for multiple tasks)
  /// and exponential backoff on HTTP 429 rate-limit responses.
  Future<SyncResult> pushTasksToGoogleTasks({
    required List<Task> tasks,
    required String? accessToken,
    TokenRefreshCallback? onTokenRefresh,
    bool useBatch = true,
  }) async {
    if (tasks.isEmpty) {
      return SyncResult.success(0, 'No tasks to sync to Google Tasks');
    }

    String? activeToken = accessToken;
    if (activeToken == null || activeToken.isEmpty) {
      final refreshFn = onTokenRefresh ?? _onTokenRefresh;
      if (refreshFn != null) {
        activeToken = await refreshFn();
      }
    }

    if (activeToken == null || activeToken.isEmpty) {
      debugPrint('Google Tasks Sync: No access token — ${tasks.length} tasks queued for next online sync');
      return SyncResult(
        itemsSynced: 0,
        isSuccess: false,
        message: 'Offline — ${tasks.length} task(s) will sync to Google Tasks when connected',
        errors: [],
      );
    }

    String currentToken = activeToken;
    int successCount = 0;
    final List<String> errorList = [];

    if (useBatch && tasks.length > 1) {
      for (int offset = 0; offset < tasks.length; offset += maxBatchSize) {
        final chunk = tasks.sublist(
          offset,
          min(offset + maxBatchSize, tasks.length),
        );
        const boundary = 'batch_medday_tasks';
        final batchBody = buildBatchPayload(chunk, boundary: boundary);

        try {
          final response = await _sendWithRetry(
            (token) => _httpClient.post(
              Uri.parse(_tasksBatchUrl),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'multipart/mixed; boundary=$boundary',
              },
              body: batchBody,
            ),
            accessToken: currentToken,
            onTokenRefresh: onTokenRefresh,
            onTokenUpdated: (updated) => currentToken = updated,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final parsed = _parseBatchResponse(response.body, chunk.length);
            successCount += parsed.successCount;
            errorList.addAll(parsed.errors);
          } else {
            final fallback = await _pushTasksIndividually(
              chunk: chunk,
              accessToken: currentToken,
              onTokenRefresh: onTokenRefresh,
              onTokenUpdated: (updated) => currentToken = updated,
            );
            successCount += fallback.itemsSynced;
            errorList.addAll(fallback.errors);
          }
        } catch (e) {
          errorList.add('Tasks batch sync error: $e');
        }
      }
    } else {
      final singleResult = await _pushTasksIndividually(
        chunk: tasks,
        accessToken: currentToken,
        onTokenRefresh: onTokenRefresh,
        onTokenUpdated: (updated) => currentToken = updated,
      );
      successCount += singleResult.itemsSynced;
      errorList.addAll(singleResult.errors);
    }

    if (successCount > 0 || errorList.isEmpty) {
      return SyncResult(
        itemsSynced: successCount,
        isSuccess: true,
        message: 'Successfully synced $successCount tasks to Google Tasks',
        errors: errorList,
      );
    } else {
      return SyncResult.failure('Failed to sync tasks to Google Tasks', errorList);
    }
  }

  Future<SyncResult> _pushTasksIndividually({
    required List<Task> chunk,
    required String accessToken,
    TokenRefreshCallback? onTokenRefresh,
    ValueChanged<String>? onTokenUpdated,
  }) async {
    String currentToken = accessToken;
    int successCount = 0;
    final List<String> errorList = [];

    for (final task in chunk) {
      try {
        final taskData = taskToGoogleTask(task);
        final response = await _sendWithRetry(
          (token) => _httpClient.post(
            Uri.parse(_tasksApiBase),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(taskData),
          ),
          accessToken: currentToken,
          onTokenRefresh: onTokenRefresh,
          onTokenUpdated: (updated) {
            currentToken = updated;
            onTokenUpdated?.call(updated);
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          successCount++;
        } else {
          errorList.add('Task "${task.title}": HTTP ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        errorList.add('Task "${task.title}": $e');
      }
    }

    return SyncResult(
      itemsSynced: successCount,
      isSuccess: successCount > 0 || errorList.isEmpty,
      message: 'Synced $successCount tasks',
      errors: errorList,
    );
  }

  _TasksBatchParseResult _parseBatchResponse(String responseBody, int expectedCount) {
    final statusMatches = RegExp(r'HTTP/1\.[01]\s+(\d{3})').allMatches(responseBody).toList();
    if (statusMatches.isEmpty) {
      return _TasksBatchParseResult(successCount: expectedCount, errors: const []);
    }

    int successes = 0;
    final List<String> errors = [];
    for (int i = 0; i < statusMatches.length; i++) {
      final code = int.tryParse(statusMatches[i].group(1) ?? '') ?? 500;
      if (code >= 200 && code < 300) {
        successes++;
      } else {
        errors.add('Batch item #${i + 1} failed with HTTP $code');
      }
    }
    return _TasksBatchParseResult(successCount: successes, errors: errors);
  }

  /// Fetch tasks from Google Tasks with automatic 429 backoff and 401 token refresh.
  Future<List<Task>> fetchGoogleTasks({
    required String? accessToken,
    bool showCompleted = true,
    TokenRefreshCallback? onTokenRefresh,
  }) async {
    String? activeToken = accessToken;
    if (activeToken == null || activeToken.isEmpty) {
      final refreshFn = onTokenRefresh ?? _onTokenRefresh;
      if (refreshFn != null) {
        activeToken = await refreshFn();
      }
    }
    if (activeToken == null || activeToken.isEmpty) {
      return [];
    }

    try {
      final queryParams = <String, String>{
        'showCompleted': showCompleted.toString(),
        'showHidden': 'true',
      };

      final uri = Uri.parse(_tasksApiBase).replace(queryParameters: queryParams);
      final response = await _sendWithRetry(
        (token) => _httpClient.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        accessToken: activeToken,
        onTokenRefresh: onTokenRefresh,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items
            .map((item) => googleTaskToDailyPlannerTask(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching Google Tasks: $e');
      return [];
    }
  }
}

class _TasksBatchParseResult {
  final int successCount;
  final List<String> errors;

  const _TasksBatchParseResult({
    required this.successCount,
    required this.errors,
  });
}
