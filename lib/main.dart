import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/auth_gate.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  await NotificationService.instance.initialize();
  runApp(const PanafixApp());
}

class PanafixApp extends StatelessWidget {
  const PanafixApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF7A00);
    const deepOrange = Color(0xFFEA580C);
    const softOrange = Color(0xFFFFE7D1);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryOrange,
      primary: primaryOrange,
      secondary: deepOrange,
      surface: const Color(0xFFFFF7F0),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Panafix',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      scaffoldMessengerKey: NotificationService.messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFFF7F0),
        canvasColor: const Color(0xFFFFF7F0),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: primaryOrange,
              width: 1.4,
            ),
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF9A3412),
          ),
          prefixIconColor: primaryOrange,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryOrange,
            side: const BorderSide(
              color: Color(0xFFFFB47A),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: deepOrange,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 82,
          backgroundColor: Colors.white,
          indicatorColor: softOrange,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? primaryOrange : const Color(0xFF756B61),
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected
                  ? const Color(0xFF1B130C)
                  : const Color(0xFF756B61),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
        ),
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: const Color(0xFF1B130C),
              displayColor: const Color(0xFF1B130C),
            ),
      ),
      home: const AuthGate(),
    );
  }
}
