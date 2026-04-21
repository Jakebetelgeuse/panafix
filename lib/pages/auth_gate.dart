import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:panafix/pages/admin_home_page.dart';
import 'package:panafix/pages/home_page.dart';
import 'package:panafix/pages/login_page.dart';
import 'package:panafix/pages/owner_access_page.dart';
import 'package:panafix/pages/role_selection_page.dart';
import 'package:panafix/pages/technician_home_page.dart';
import 'package:panafix/services/notification_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Map<String, dynamic>?> _ensureUserProfile(User user) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (snapshot.exists) {
      return snapshot.data();
    }

    final fallbackData = {
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'role': 'pending',
      'needsRoleSelection': true,
      'showOnboardingGuide': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await userRef.set(fallbackData, SetOptions(merge: true));

    final rebuiltSnapshot = await userRef.get();
    return rebuiltSnapshot.data();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _ensureUserProfile(user),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No pudimos preparar tu perfil: ${userSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final data = userSnapshot.data;
            final role = data?['role'] ?? 'client';
            final needsRoleSelection = data?['needsRoleSelection'] == true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              NotificationService.instance.syncCurrentUserToken();
            });

            if (needsRoleSelection || role == 'pending') {
              return const RoleSelectionPage();
            }

            if (role == 'owner') {
              return const OwnerAccessPage();
            }

            if (role == 'admin') {
              return const AdminHomePage();
            }

            if (role == 'technician') {
              return const TechnicianHomePage();
            }

            return const HomePage();
          },
        );
      },
    );
  }
}
