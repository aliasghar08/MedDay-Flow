import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Service managing Sign in with Apple authentication flow and Firebase integration.
class AppleSignInService {
  /// Generates a cryptographically secure random nonce string.
  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Hashes a string using SHA-256.
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check whether Sign in with Apple is supported on this platform/device.
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await SignInWithApple.isAvailable();
    } catch (e) {
      debugPrint('Apple Sign-In isAvailable check error: $e');
      return false;
    }
  }

  /// Initiates the Apple Sign-In flow, exchanges credentials with Firebase Auth,
  /// and returns the resulting [UserCredential].
  ///
  /// Returns `null` if the user cancels the authorization sheet.
  static Future<UserCredential?> signInWithFirebase() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Apple only transmits name info on the first authorization.
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      String? fullName;
      if (givenName != null || familyName != null) {
        fullName = [givenName, familyName]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(' ')
            .trim();
      }

      if (fullName != null &&
          fullName.isNotEmpty &&
          userCredential.user != null) {
        if (userCredential.user!.displayName == null ||
            userCredential.user!.displayName!.isEmpty) {
          try {
            await userCredential.user!.updateDisplayName(fullName);
          } catch (e) {
            debugPrint('Non-fatal error updating displayName: $e');
          }
        }
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('Apple Sign-In cancelled by user.');
        return null;
      }
      debugPrint('Apple Sign-In authorization error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      rethrow;
    }
  }
}

