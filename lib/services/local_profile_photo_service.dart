import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../repositories/device_features.dart';

class NativePhotoPicker implements PhotoPicker {
  NativePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  @override
  Future<XFile?> pick(ProfilePhotoSource source) async {
    try {
      return await _picker.pickImage(
        source: source == ProfilePhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
        requestFullMetadata: false,
      );
    } on PlatformException {
      throw const PhotoFailure(
        'Não foi possível abrir a câmera ou galeria. Verifique as permissões e tente novamente.',
      );
    }
  }

  @override
  Future<XFile?> recover() async {
    final result = await _picker.retrieveLostData();
    if (result.exception != null) {
      throw const PhotoFailure(
        'Não foi possível recuperar a seleção de foto anterior. Tente selecionar novamente.',
      );
    }
    return result.files?.firstOrNull;
  }
}

class LocalProfilePhotoService implements ProfilePhotoRepository {
  LocalProfilePhotoService({
    PhotoPicker? picker,
    Future<Directory> Function()? directory,
  }) : _picker = picker ?? NativePhotoPicker(),
       _directory = directory ?? getApplicationSupportDirectory;
  final PhotoPicker _picker;
  final Future<Directory> Function() _directory;
  Future<void>? _recovery;
  bool _choosing = false;
  Future<Directory> _root() async =>
      Directory(path.join((await _directory()).path, 'profile_photos'))
        ..createSync(recursive: true);
  String _ownerKey(String uid) =>
      base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
  Future<Directory> _owner(String uid) async =>
      Directory(path.join((await _root()).path, _ownerKey(uid)))
        ..createSync(recursive: true);
  Future<void> _atomicJson(File file, Map<String, Object?> data) async {
    final temporary = File('${file.path}.${const Uuid().v4()}.tmp');
    try {
      await temporary.writeAsString(jsonEncode(data), flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> recoverLostSelection() => _recovery ??= _recover();
  Future<void> _recover() async {
    try {
      final marker = File(
        path.join((await _root()).path, 'pending_selection.json'),
      );
      final owner = await _readJson(marker);
      final recovered = await _picker.recover();
      if (owner?['userId'] is String && recovered != null) {
        await _commit(owner!['userId'] as String, recovered);
      }
      if (await marker.exists()) await marker.delete();
    } catch (_) {
      _recovery = null;
      throw const PhotoFailure(
        'Não foi possível recuperar a foto anterior. Tente novamente.',
      );
    }
  }

  Future<String?> _load(String uid) async {
    final directory = await _owner(uid);
    final manifest = File(path.join(directory.path, 'photo.json'));
    final data = await _readJson(manifest);
    final name = data?['file'] as String?;
    if (name == null || path.basename(name) != name) return null;
    final photo = File(path.join(directory.path, name));
    return await photo.exists() ? photo.path : null;
  }

  @override
  Future<String?> load(String userId) async {
    try {
      await recoverLostSelection();
      return await _load(userId);
    } on PhotoFailure {
      rethrow;
    } catch (_) {
      throw const PhotoFailure(
        'Não foi possível carregar a foto deste aparelho.',
      );
    }
  }

  Future<String> _commit(String uid, XFile selection) async {
    final length = await selection.length();
    if (length == 0 || length > 10 * 1024 * 1024) {
      throw const PhotoFailure('Escolha uma imagem de até 10 MB.');
    }
    final directory = await _owner(uid);
    final previous = await _load(uid);
    final extension = path.extension(selection.path).toLowerCase();
    final suffix =
        ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(extension)
        ? extension
        : '.jpg';
    final photo = File(
      path.join(directory.path, '${const Uuid().v4()}$suffix'),
    );
    try {
      await selection.saveTo(photo.path);
      await _atomicJson(File(path.join(directory.path, 'photo.json')), {
        'file': path.basename(photo.path),
      });
    } catch (_) {
      if (await photo.exists()) await photo.delete();
      rethrow;
    }
    if (previous != null && previous != photo.path) {
      try {
        await File(previous).delete();
      } on FileSystemException {
        /* A referência já foi substituída. */
      }
    }
    return photo.path;
  }

  @override
  Future<String?> choose(String userId, ProfilePhotoSource source) async {
    if (_choosing) {
      throw const PhotoFailure('Aguarde a seleção de foto em andamento.');
    }
    _choosing = true;
    File? marker;
    try {
      await recoverLostSelection();
      marker = File(path.join((await _root()).path, 'pending_selection.json'));
      await _atomicJson(marker, {'userId': userId});
      final selected = await _picker.pick(source);
      return selected == null ? null : await _commit(userId, selected);
    } on PhotoFailure {
      rethrow;
    } catch (_) {
      throw const PhotoFailure(
        'Não foi possível salvar a foto. Sua imagem anterior foi mantida.',
      );
    } finally {
      _choosing = false;
      if (marker != null) {
        try {
          if (await marker.exists()) await marker.delete();
        } on FileSystemException {
          /* Recuperável na próxima inicialização. */
        }
      }
    }
  }

  @override
  Future<void> remove(String userId) async {
    try {
      final previous = await _load(userId);
      final manifest = File(
        path.join((await _owner(userId)).path, 'photo.json'),
      );
      if (await manifest.exists()) await manifest.delete();
      if (previous != null) {
        try {
          await File(previous).delete();
        } on FileSystemException {
          /* A referência foi removida. */
        }
      }
    } catch (_) {
      throw const PhotoFailure(
        'Não foi possível remover a foto. Tente novamente.',
      );
    }
  }
}
