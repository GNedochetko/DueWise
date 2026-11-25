import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/app_features.dart';
import 'models/app_user.dart';
import 'repositories/auth_repository.dart';
import 'repositories/activity_repository.dart';
import 'repositories/profile_repository.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/app_shell.dart';
import 'screens/startup/startup_screen.dart';

class DueWiseApp extends StatelessWidget {
  const DueWiseApp({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.activityRepository,
    required this.features,
  });
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ActivityRepository activityRepository;
  final AppFeatures features;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DueWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AuthGate(
        authRepository: authRepository,
        profileRepository: profileRepository,
        activityRepository: activityRepository,
        features: features,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authRepository,
    required this.profileRepository,
    required this.activityRepository,
    required this.features,
  });
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ActivityRepository activityRepository;
  final AppFeatures features;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<AppUser?> _userChanges;
  String? _sessionUserId;
  @override
  void initState() {
    super.initState();
    _userChanges = widget.authRepository.userChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userChanges,
      initialData: widget.authRepository.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StartupScreen(
            hasError: true,
            onRetry: () => setState(
              () => _userChanges = widget.authRepository.userChanges,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const StartupScreen();
        }
        final user = snapshot.data;
        if (_sessionUserId != null && _sessionUserId != user?.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(this.context).popUntil((route) => route.isFirst);
            }
          });
        }
        _sessionUserId = user?.id;
        if (user == null) return AuthScreen(repository: widget.authRepository);
        return AppShell(
          key: ValueKey(user.id),
          user: user,
          authRepository: widget.authRepository,
          profileRepository: widget.profileRepository,
          activityRepository: widget.activityRepository,
          features: widget.features,
        );
      },
    );
  }
}
