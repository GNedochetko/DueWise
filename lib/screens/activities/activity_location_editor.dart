import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inline_message.dart';
import '../../repositories/device_features.dart';

class ActivityLocationEditor extends StatefulWidget {
  const ActivityLocationEditor({
    super.key,
    required this.service,
    required this.onChanged,
    required this.onBusyChanged,
    this.initialValue,
    this.enabled = true,
  });
  final LocationService service;
  final Coordinates? initialValue;
  final ValueChanged<Coordinates?> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;
  @override
  State<ActivityLocationEditor> createState() => _ActivityLocationEditorState();
}

class _ActivityLocationEditorState extends State<ActivityLocationEditor> {
  Coordinates? _coordinates;
  var _busy = false;
  LocationFailure? _error;
  @override
  void initState() {
    super.initState();
    _coordinates = widget.initialValue;
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      final position = await widget.service.capture();
      if (!mounted) return;
      setState(() => _coordinates = position);
      widget.onChanged(position);
    } on LocationFailure catch (error) {
      if (mounted) setState(() => _error = error);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const LocationFailure(
            'Não foi possível obter a localização.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Future<void> _openSettings() async {
    try {
      await widget.service.openSettings(_error!.resolution);
    } on LocationFailure catch (error) {
      if (mounted) setState(() => _error = error);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const LocationFailure(
            'Não foi possível abrir as configurações.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Localização atual (opcional)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Registre onde você está no momento da captura.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('capture-location'),
        onPressed: !widget.enabled || _busy ? null : _capture,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location, size: 18),
        label: Text(_busy ? 'Obtendo localização…' : 'Usar localização atual'),
      ),
      if (_coordinates != null) ...[
        const SizedBox(height: 8),
        SelectableText(
          'Latitude: ${_coordinates!.latitude.toStringAsFixed(6)}\nLongitude: ${_coordinates!.longitude.toStringAsFixed(6)}',
          key: const Key('location-coordinates'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('remove-location'),
            onPressed: !widget.enabled || _busy
                ? null
                : () {
                    setState(() => _coordinates = null);
                    widget.onChanged(null);
                  },
            child: const Text('Remover localização'),
          ),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        InlineMessage(message: _error!.message),
        if (_error!.resolution != LocationResolution.none)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('location-settings'),
              onPressed: _openSettings,
              child: const Text('Abrir configurações'),
            ),
          ),
      ],
    ],
  );
}
