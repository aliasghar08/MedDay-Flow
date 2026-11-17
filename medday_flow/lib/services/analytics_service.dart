import 'package:flutter/foundation.dart';

/// Lightweight, dependency-free analytics telemetry service.
/// Safely logs personalization, medication, and user interaction events.
class AnalyticsService {
  AnalyticsService._();

  /// Logs an analytics event safely wrapped in try/catch.
  static void logEvent(String name, [Map<String, dynamic>? parameters]) {
    try {
      if (kDebugMode) {
        debugPrint('📊 [Analytics] $name: $parameters');
      }
      // Can be connected to FirebaseAnalytics or any external telemetry if configured
    } catch (e) {
      debugPrint('⚠️ AnalyticsService logEvent error ($name): $e');
    }
  }

  /// Safely logs a personalization applied event.
  static void logPersonalizationApplied({
    required String type,
    Map<String, dynamic>? parameters,
  }) {
    try {
      final payload = {
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        if (parameters != null) ...parameters,
      };
      logEvent('personalization_applied', payload);
    } catch (e) {
      debugPrint('⚠️ AnalyticsService logPersonalizationApplied error: $e');
    }
  }

  /// Safely logs a personalization dismissed event.
  static void logPersonalizationDismissed({
    required String type,
    Map<String, dynamic>? parameters,
  }) {
    try {
      final payload = {
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        if (parameters != null) ...parameters,
      };
      logEvent('personalization_dismissed', payload);
    } catch (e) {
      debugPrint('⚠️ AnalyticsService logPersonalizationDismissed error: $e');
    }
  }
}

