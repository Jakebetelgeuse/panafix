import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  GoogleSignIn? get _googleSignIn => kIsWeb ? null : GoogleSignIn();

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();

      googleProvider.setCustomParameters({
        'prompt': 'select_account',
      });

      final userCredential =
      await FirebaseAuth.instance.signInWithPopup(googleProvider);

      await _saveUserIfNeeded(
        userCredential.user,
        requireRoleSelection: userCredential.additionalUserInfo?.isNewUser ?? false,
      );

      return userCredential;
    } else {
      final googleSignIn = _googleSignIn!;
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-cancelled',
          message: 'El inicio de sesión con Google fue cancelado',
        );
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await _saveUserIfNeeded(
        userCredential.user,
        requireRoleSelection: userCredential.additionalUserInfo?.isNewUser ?? false,
      );

      return userCredential;
    }
  }

  Future<UserCredential> signInWithFacebook() async {
    if (kIsWeb) {
      final facebookProvider = FacebookAuthProvider();

      facebookProvider.setCustomParameters({
        'display': 'popup',
      });

      final userCredential =
      await FirebaseAuth.instance.signInWithPopup(facebookProvider);

      await _saveUserIfNeeded(
        userCredential.user,
        requireRoleSelection: userCredential.additionalUserInfo?.isNewUser ?? false,
      );

      return userCredential;
    } else {
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final OAuthCredential credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );

        await _saveUserIfNeeded(
          userCredential.user,
          requireRoleSelection: userCredential.additionalUserInfo?.isNewUser ?? false,
        );

        return userCredential;
      } else if (result.status == LoginStatus.cancelled) {
        throw FirebaseAuthException(
          code: 'facebook-sign-in-cancelled',
          message: 'El inicio de sesión con Facebook fue cancelado',
        );
      } else {
        throw FirebaseAuthException(
          code: 'facebook-login-failed',
          message: result.message ?? 'Error al iniciar sesión con Facebook',
        );
      }
    }
  }

  Future<void> _saveUserIfNeeded(
    User? user, {
    required bool requireRoleSelection,
  }) async {
    if (user == null) return;

    final userRef =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'role': requireRoleSelection ? 'pending' : 'client',
        'needsRoleSelection': requireRoleSelection,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();

    if (!kIsWeb) {
      unawaited(_clearSocialSessions());
    }
  }

  Future<void> _clearSocialSessions() async {
    final googleSignIn = _googleSignIn;
    try {
      await googleSignIn?.disconnect().timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        await googleSignIn?.signOut().timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    try {
      await FacebookAuth.instance.logOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
