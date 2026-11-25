import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/inline_message.dart';
import '../../core/widgets/page_content.dart';
import '../../models/user_profile.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/device_features.dart';
import 'profile_photo_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.photos,
    required this.repository,
    required this.authRepository,
    required this.onSaved,
  });
  final UserProfile profile;
  final ProfilePhotoRepository photos;
  final ProfileRepository repository;
  final AuthRepository authRepository;
  final ValueChanged<UserProfile> onSaved;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _course;
  late final TextEditingController _institution;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _course = TextEditingController(text: widget.profile.course);
    _institution = TextEditingController(text: widget.profile.institution);
  }

  @override
  void dispose() {
    _name.dispose();
    _course.dispose();
    _institution.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final profile = UserProfile(
      userId: widget.profile.userId,
      email: widget.profile.email,
      name: _name.text.trim(),
      course: _course.text.trim(),
      institution: _institution.text.trim(),
    );
    try {
      await widget.repository.save(profile);
      if (!mounted) return;
      widget.onSaved(profile);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil salvo.')));
    } on ProfileFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível salvar seu perfil. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageContent(
      maxWidth: 520,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfilePhotoSection(
              userId: widget.profile.userId,
              repository: widget.photos,
            ),
            const SizedBox(height: 8),
            Text(
              'Dados pessoais',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.profile.email,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              InlineMessage(message: _error!),
              const SizedBox(height: 20),
            ],
            TextFormField(
              key: const Key('profile-name'),
              controller: _name,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: Validators.name,
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('profile-course'),
              controller: _course,
              enabled: !_saving,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Curso (opcional)'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('profile-institution'),
              controller: _institution,
              enabled: !_saving,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Instituição (opcional)',
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('save-profile'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvar perfil'),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            SignOutButton(repository: widget.authRepository, enabled: !_saving),
          ],
        ),
      ),
    );
  }
}

class SignOutButton extends StatefulWidget {
  const SignOutButton({
    super.key,
    required this.repository,
    this.enabled = true,
  });
  final AuthRepository repository;
  final bool enabled;
  @override
  State<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<SignOutButton> {
  bool _busy = false;
  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível sair. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const Key('sign-out'),
    onPressed: _busy || !widget.enabled ? null : _signOut,
    icon: const Icon(Icons.logout),
    label: Text(_busy ? 'Saindo…' : 'Sair da conta'),
  );
}
