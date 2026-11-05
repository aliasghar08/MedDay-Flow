import 'package:flutter/material.dart';

/// Reusable legal and medical disclaimer viewer for MedDay Flow.
/// Fulfills App Store Review Guidelines 1.4.1 (Medical Disclaimers),
/// 5.1.1 (Privacy Policy in-app access), and 5.1.2 (HealthKit Data Use).
class LegalView {
  static const String medicalDisclaimerText = '''
Important Medical Notice:
MedDay Flow is designed strictly as a personal productivity and adherence assistant to help you organize reminders, track routines, and log taken medication doses.

1. NOT A MEDICAL DEVICE OR CLINICAL SERVICE:
MedDay Flow is NOT a medical device, diagnostic tool, clinical guidance system, or licensed healthcare provider. The app does not evaluate medical symptoms, diagnose health conditions, prescribe treatments, or provide clinical advice.

2. NO DOCTOR-PATIENT RELATIONSHIP:
Use of MedDay Flow does not create a doctor-patient, pharmacist-patient, or any other healthcare provider relationship.

3. ALWAYS CONSULT YOUR PHYSICIAN:
Always consult your doctor, pharmacist, or licensed healthcare provider before starting, stopping, or altering any medication, dosage, timing, or treatment plan. Never disregard, avoid, or delay seeking professional medical advice because of information recorded or viewed in MedDay Flow.

4. MEDICAL EMERGENCIES:
If you are experiencing a medical emergency, adverse drug reaction, or life-threatening condition, immediately call your local emergency services (e.g., 911 or 112) or go to the nearest emergency room.
''';

  static const String privacyPolicyText = '''
MedDay Flow Privacy Policy
Effective Date: September 29, 2026
Developer: Ali Asghar (DartNexus Lab)

1. Overview & Commitment
We respect your privacy. This Privacy Policy details how MedDay Flow collects, uses, stores, and protects your information.

2. Information We Collect
• Account Information: Email address, display name, and authentication tokens (managed securely via Firebase Auth and Apple Sign-In).
• Medication & Schedule Data: Medication names, dosage amounts, scheduled reminder times, and intake completion records.
• Biometric Credentials: Face ID or Passkey biometrics are processed exclusively on your device via iOS LocalAuthentication and are NEVER transmitted or stored on remote servers.

3. Health Data
• MedDay Flow does not integrate with Apple Health (HealthKit) on iOS. Medication schedules and intake logs are stored in your MedDay Flow account only.
• On Android, if you opt in, taken doses can be synced to Google Fit / Health Connect.
• MedDay Flow does NOT use health data for advertising, marketing, profiling, or data mining, and does NOT sell, rent, or transfer it to third parties.

4. Data Security & Storage
• All data transmission occurs over encrypted HTTPS/TLS channels.
• Cloud storage is backed by Firebase Security Rules enforcing per-user data isolation.

5. User Rights & Account Deletion (Guideline 5.1.1)
• You have the right to access, edit, or permanently delete your account and all associated data at any time directly in Settings > Danger Zone > Delete Account.

6. Contact
For questions regarding this policy, contact us at:
https://github.com/aliasghar08
''';

  static const String termsOfServiceText = '''
MedDay Flow Terms of Service
Effective Date: September 29, 2026

1. Acceptance of Terms
By downloading, accessing, or using MedDay Flow, you agree to be bound by these Terms of Service. If you do not agree, do not use the application.

2. Use of Service
MedDay Flow is provided for personal, non-commercial medication tracking and routine scheduling. You are solely responsible for ensuring the accuracy of schedules and doses entered.

3. No Medical Warranty
MedDay Flow does not warrant that notifications or alarms will be error-free or uninterrupted. Device battery states, system sleep modes, and permission configurations may impact alerts. Do not rely solely on the app for critical, life-dependent medications.

4. Limitation of Liability
To the maximum extent permitted by applicable law, MedDay Flow and its developers disclaim liability for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use the application.

5. Termination & Data Removal
You may discontinue using the application and delete your account and data at any time via in-app settings.
''';

  static void showMedicalDisclaimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Medical Disclaimer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            medicalDisclaimerText,
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  static void showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Privacy Policy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            privacyPolicyText,
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static void showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Terms of Service',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            termsOfServiceText,
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static void openLegalPage(BuildContext context, {int initialTab = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalInfoPage(initialIndex: initialTab),
      ),
    );
  }
}

/// Dedicated Screen displaying Legal & Medical policies with Tab navigation
class LegalInfoPage extends StatelessWidget {
  final int initialIndex;
  const LegalInfoPage({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      initialIndex: initialIndex.clamp(0, 2),
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Legal & Compliance'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Color(0xFF2563EB),
            indicatorColor: Color(0xFF2563EB),
            tabs: [
              Tab(text: 'Medical Disclaimer', icon: Icon(Icons.health_and_safety_outlined, size: 20)),
              Tab(text: 'Privacy Policy', icon: Icon(Icons.privacy_tip_outlined, size: 20)),
              Tab(text: 'Terms of Service', icon: Icon(Icons.description_outlined, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabContent(
              context: context,
              isDark: isDark,
              title: 'Medical & Health Disclaimer',
              subtitle: 'Compliance with App Store Review Guideline 1.4.1',
              text: LegalView.medicalDisclaimerText,
              icon: Icons.health_and_safety_rounded,
              iconColor: const Color(0xFF2563EB),
            ),
            _buildTabContent(
              context: context,
              isDark: isDark,
              title: 'Privacy Policy',
              subtitle: 'Compliance with App Store Review Guidelines 5.1.1 & 5.1.2',
              text: LegalView.privacyPolicyText,
              icon: Icons.privacy_tip_outlined,
              iconColor: const Color(0xFF10B981),
            ),
            _buildTabContent(
              context: context,
              isDark: isDark,
              title: 'Terms of Service',
              subtitle: 'General Terms & Conditions of Usage',
              text: LegalView.termsOfServiceText,
              icon: Icons.description_outlined,
              iconColor: const Color(0xFF6366F1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required String text,
    required IconData icon,
    required Color iconColor,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

