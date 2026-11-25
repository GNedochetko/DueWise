import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inline_message.dart';
import '../../repositories/device_features.dart';

enum _PhotoAction { gallery, camera, remove }

class ProfilePhotoSection extends StatefulWidget {
  const ProfilePhotoSection({
    super.key,
    required this.userId,
    required this.repository,
  });
  final String userId;
  final ProfilePhotoRepository repository;
  @override
  State<ProfilePhotoSection> createState() => _ProfilePhotoSectionState();
}

class _ProfilePhotoSectionState extends State<ProfilePhotoSection> {
  String? _path;
  String? _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = await widget.repository.load(widget.userId);
      if (mounted) setState(() => _path = path);
    } on PhotoFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar sua foto.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change() async {
    if (_busy) return;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, _PhotoAction.gallery),
            ),
            ListTile(
              key: const Key('photo-camera'),
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, _PhotoAction.camera),
            ),
            if (_path != null)
              ListTile(
                key: const Key('photo-remove'),
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remover foto'),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == _PhotoAction.remove) {
        await widget.repository.remove(widget.userId);
        if (mounted) setState(() => _path = null);
      } else {
        final photo = await widget.repository.choose(
          widget.userId,
          action == _PhotoAction.camera
              ? ProfilePhotoSource.camera
              : ProfilePhotoSource.gallery,
        );
        if (photo != null && mounted) setState(() => _path = photo);
      }
    } on PhotoFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível alterar a foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Semantics(
            label: 'Foto de perfil',
            image: true,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: _path == null
                      ? const ColoredBox(
                          color: AppColors.paleBlue,
                          child: Icon(
                            Icons.person_outline,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        )
                      : Image.file(
                          File(_path!),
                          key: const Key('profile-photo'),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const ColoredBox(
                                color: AppColors.paleBlue,
                                child: Icon(
                                  Icons.person_outline,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            key: const Key('change-photo'),
            onPressed: _busy ? null : _change,
            child: Text(_busy ? 'Aguarde…' : 'Alterar foto'),
          ),
        ),
        const Text(
          'Foto salva somente neste aparelho.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          InlineMessage(message: _error!),
        ],
      ],
    ),
  );
}
