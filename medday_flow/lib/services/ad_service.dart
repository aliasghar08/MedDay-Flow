import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Central Ad Service managing Google Mobile Ads initialization,
/// App Tracking Transparency (ATT) authorization, and Ad Unit ID routing.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  Completer<void>? _initCompleter;

  /// Production Banner Unit ID from AdMob
  static const String _productionIosBannerId =
      'ca-app-pub-9402443776639153/8317724625';
  static const String _testIosBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testAndroidBannerId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Returns official Google test banner ID in debug mode,
  /// and your configured production AdMob banner ID in release builds.
  String get bannerAdUnitId {
    if (kDebugMode) {
      return (!kIsWeb && Platform.isAndroid)
          ? _testAndroidBannerId
          : _testIosBannerId;
    }

    if (!kIsWeb && Platform.isIOS) {
      if (_productionIosBannerId.contains('<YOUR_BANNER_UNIT_SUFFIX>')) {
        debugPrint(
            'AdService: Warning - Production Banner ID placeholder still set. Falling back to test ID.');
        return _testIosBannerId;
      }
      return _productionIosBannerId;
    }

    return _testAndroidBannerId;
  }

  /// Initializes AdMob and handles Apple's App Tracking Transparency prompt safely.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      // 1. Request App Tracking Transparency permission on iOS
      if (Platform.isIOS) {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          final newStatus =
              await AppTrackingTransparency.requestTrackingAuthorization();
          debugPrint('AdService: ATT authorization result: $newStatus');
        } else {
          debugPrint('AdService: ATT status already determined: $status');
        }
      }

      // 2. Initialize Google Mobile Ads SDK
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ AdService: MobileAds initialized successfully');
    } catch (e) {
      debugPrint('❌ AdService: Initialization failed: $e');
    } finally {
      _initCompleter?.complete();
    }
  }
}

