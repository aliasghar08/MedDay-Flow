import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Service managing Sign in with Apple authentication flow and Firebase integration.
class AppleSignInService {
  /// Firebase Auth OAuth redirect handler for project daily-planner-593d8.
  static const String redirectUri =
      'https://daily-planner-593d8.firebaseapp.com/__/auth/handler';

  /// Apple Services ID configured in Apple Developer and Firebase Console.
  static const String defaultClientId =
      'com.dartnexuslab.meddayflow.signin';

  /// Generates a cryptographically secure random nonce string.
  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Hashes a string using SHA-256 hex digest.
  static String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Check whether Sign in with Apple is supported on this platform/device.
  static Future<bool> isAvailable() async {
    if (kIsWeb) return true;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        return await SignInWithApple.isAvailable();
      }
      // On Android / other platforms, web OAuth with redirect handler is supported
      return true;
    } catch (e) {
      debugPrint('Apple Sign-In isAvailable check error: $e');
      return false;
    }
  }

  /// Initiates the Apple Sign-In flow, exchanges credentials with Firebase Auth,
  /// and returns the resulting [UserCredential].
  ///
  /// Returns `null` if the user cancels the authorization sheet.
  static Future<UserCredential?> signInWithFirebase({
    String? clientId,
    String? customRedirectUri,
  }) async {
    try {
      // 1. Generate a single rawNonce and its SHA-256 hex digest
      final rawNonce = _generateNonce();
      final sha256Nonce = _sha256ofString(rawNonce);

      // 2. Ensure webAuthenticationOptions is strictly null on iOS so native
      // AuthenticationServices sheet is used instead of a web Services ID flow.
      final webAuthOptions = (!kIsWeb && Platform.isIOS)
          ? null
          : WebAuthenticationOptions(
              clientId: clientId ?? defaultClientId,
              redirectUri: Uri.parse(customRedirectUri ?? redirectUri),
            );

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256Nonce,
        webAuthenticationOptions: webAuthOptions,
      );

      // 3. Guard against missing identity token
      final idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'null-identity-token',
          message: 'Apple ID Credential did not include an identityToken. Ensure Sign in with Apple capability is enabled.',
        );
      }

      // 4. Create OAuth credential with idToken, rawNonce, and accessToken (authorizationCode).
      // Recent firebase_auth versions require the Apple authorizationCode to complete the OAuth
      // handshake with Apple. If the project configuration rejects it, we seamlessly fall back
      // to idToken + rawNonce only.
      final authCode = appleCredential.authorizationCode.isNotEmpty
          ? appleCredential.authorizationCode
          : null;

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      UserCredential userCredential;

      try {
        final AuthCredential credential = oAuthProvider.credential(
          idToken: idToken,
          rawNonce: rawNonce,
          accessToken: authCode,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential' && authCode != null) {
          debugPrint(
            'Apple Sign-In with authorizationCode returned invalid-credential: ${e.message}. '
            'Retrying with idToken & rawNonce only...',
          );
          final fallbackCredential = oAuthProvider.credential(
            idToken: idToken,
            rawNonce: rawNonce,
          );
          userCredential = await FirebaseAuth.instance
              .signInWithCredential(fallbackCredential);
        } else {
          rethrow;
        }
      }

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
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Apple Sign-In error: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      rethrow;
    }
  }
}
