import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/startup/startup_screen.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_profile_service.dart';
import 'services/local_database.dart';
import 'services/sqlite_activity_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DueWiseBootstrap());
}

class DueWiseBootstrap extends StatefulWidget {
  const DueWiseBootstrap({super.key, this.initializeFirebase});
  final Future<void> Function()? initializeFirebase;
  @override
  State<DueWiseBootstrap> createState() => _DueWiseBootstrapState();
}

class _DueWiseBootstrapState extends State<DueWiseBootstrap> {
  late Future<void> _initialization;
  late final _activities = SqliteActivityRepository(LocalDatabase());

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    if (widget.initializeFirebase != null) {
      return widget.initializeFirebase!();
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await FirebaseAuth.instance.setLanguageCode('pt-BR');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return DueWiseApp(
            activityRepository: _activities,
            authRepository: FirebaseAuthService(FirebaseAuth.instance),
            profileRepository: FirestoreProfileService(
              FirebaseFirestore.instance,
            ),
          );
        }
        return MaterialApp(
          title: 'DueWise',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: StartupScreen(
            hasError: snapshot.hasError,
            configurationMissing: snapshot.error is UnsupportedError,
            onRetry: () => setState(() {
              _initialization = _initialize();
            }),
          ),
        );
      },
    );
  }
}
