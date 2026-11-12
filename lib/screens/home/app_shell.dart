import 'package:flutter/material.dart';
import '../../controllers/activity_controller.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/inline_message.dart';
import '../../core/widgets/page_content.dart';
import '../../models/academic_activity.dart';
import '../../models/app_user.dart';
import '../../models/user_profile.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../activities/activity_details_screen.dart';
import '../activities/activity_form_screen.dart';
import '../calendar/calendar_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.authRepository,
    required this.profileRepository,
    required this.activityRepository,
  });
  final AppUser user;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ActivityRepository activityRepository;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  var _index = 0;
  var _selectedDay = DateTime.now();
  late Future<UserProfile> _profile;
  late final ActivityController _activities;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profile = widget.profileRepository.load(widget.user);
    _activities = ActivityController(
      userId: widget.user.id,
      repository: widget.activityRepository,
    )..load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.name != widget.user.name)
      _profile = widget.profileRepository.load(widget.user);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activities.dispose();
    super.dispose();
  }

  Future<void> _toggle(AcademicActivity activity) async {
    try {
      await _activities.setCompleted(activity.id, !activity.completed);
    } on ActivityFailure catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _openActivity(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ActivityDetailsScreen(controller: _activities, activityId: id),
    ),
  );
  void _createActivity() => Navigator.of(context).push(
    MaterialPageRoute<bool>(
      builder: (_) => ActivityFormScreen(
        controller: _activities,
        initialDate: _index == 1 ? _selectedDay : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _activities,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: _index == 0
            ? const BrandLogo(size: 32)
            : Text(_index == 1 ? 'Calendário' : 'Perfil'),
      ),
      body: FutureBuilder<UserProfile>(
        future: _profile,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (_index == 0)
            return HomeScreen(
              name: profile?.name ?? widget.user.name,
              controller: _activities,
              onOpenActivity: _openActivity,
              onToggle: _toggle,
            );
          if (_index == 1)
            return CalendarScreen(
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() => _selectedDay = day),
              controller: _activities,
              onOpenActivity: _openActivity,
              onToggle: _toggle,
            );
          if (snapshot.hasError) {
            final error = snapshot.error;
            return PageContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineMessage(
                    message: error is ProfileFailure
                        ? error.message
                        : 'Não foi possível carregar seu perfil.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _profile = widget.profileRepository.load(widget.user);
                    }),
                    child: const Text('Tentar novamente'),
                  ),
                  const SizedBox(height: 16),
                  SignOutButton(repository: widget.authRepository),
                ],
              ),
            );
          }
          if (profile == null)
            return const Center(child: CircularProgressIndicator());
          return ProfileScreen(
            key: ValueKey(widget.user.id),
            profile: profile,
            repository: widget.profileRepository,
            authRepository: widget.authRepository,
            onSaved: (updated) => setState(() {
              _profile = Future.value(updated);
            }),
          );
        },
      ),
      floatingActionButton:
          _index == 2 || _activities.loading || _activities.error != null
          ? null
          : FloatingActionButton(
              key: const Key('new-activity'),
              onPressed: _createActivity,
              tooltip: 'Nova atividade',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendário',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    ),
  );
}
