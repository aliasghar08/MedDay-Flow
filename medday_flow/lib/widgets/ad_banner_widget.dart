import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:medday_flow/services/ad_service.dart';

/// Reusable Google Mobile Ads banner widget.
/// - Full-width native dock with theme-aware background color.
/// - Crisp top divider and subtle shadow separating scrollable content from the ad.
/// - Safe area integration ensuring the bottom background fills the iPhone home indicator seamlessly.
/// - Headroom padding so the Google test mode overlay does not overflow into screen content.
/// - Automatically collapses when the keyboard is active to prevent blocking form inputs.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    if (kIsWeb) return;

    await AdService.instance.initialize();
    if (!mounted) return;

    _bannerAd?.dispose();
    _bannerAd = null;

    final ad = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdBannerWidget: Failed to load banner ad: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
            // Auto retry after 5s
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_isLoaded) {
                _loadBanner();
              }
            });
          }
        },
      ),
    );

    ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide completely when keyboard is active to prevent blocking form inputs
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 80;
    if (isKeyboardOpen || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dockBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: dockBg,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          // Top padding provides headroom for the Google test mode pill
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1.0,
            child: SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ),
      ),
    );
  }
}
