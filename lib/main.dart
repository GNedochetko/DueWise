import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app.dart';
import 'core/app_features.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/startup/startup_screen.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_profile_service.dart';
import 'services/local_database.dart';
import 'services/sqlite_activity_repository.dart';
import 'services/synchronized_activity_repository.dart';
import 'services/firestore_activity_service.dart';
import 'services/device_connection_monitor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.light.appBarTheme.systemOverlayStyle!,
  );
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
  late final _features = AppFeatures.device();
  late final _activities = SynchronizedActivityRepository(
    local: SqliteActivityRepository(LocalDatabase()),
    remote: FirestoreActivityService(FirebaseFirestore.instance),
    connection: DeviceConnectionMonitor(),
  );

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
    try {
      await _features.photos.recoverLostSelection();
    } catch (_) {
      /* Uma falha na foto não bloqueia o acesso à agenda. */
    }
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
            features: _features,
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
