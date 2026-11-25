import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/inline_message.dart';
import '../../models/activity_address.dart';
import '../../repositories/device_features.dart';

class ActivityAddressEditor extends StatefulWidget {
  const ActivityAddressEditor({
    super.key,
    required this.lookup,
    required this.onChanged,
    required this.onBusyChanged,
    this.initialValue,
    this.enabled = true,
  });
  final AddressLookup lookup;
  final ActivityAddress? initialValue;
  final ValueChanged<ActivityAddress?> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled;
  @override
  State<ActivityAddressEditor> createState() => _ActivityAddressEditorState();
}

class _ActivityAddressEditorState extends State<ActivityAddressEditor> {
  final _controllers = <String, TextEditingController>{};
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final values = widget.initialValue?.toMap() ?? {};
    for (final key in [
      'cep',
      'street',
      'neighborhood',
      'city',
      'state',
      'number',
      'complement',
    ]) {
      _controllers[key] = TextEditingController(
        text: values[key] as String? ?? '',
      )..addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() {
    final address = ActivityAddress.fromMap({
      for (final entry in _controllers.entries)
        entry.key: entry.key == 'state'
            ? entry.value.text.trim().toUpperCase()
            : entry.value.text.trim(),
    });
    widget.onChanged(address.isEmpty ? null : address);
  }

  Future<void> _lookup() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged(true);
    try {
      final address = await widget.lookup.lookup(_controllers['cep']!.text);
      if (!mounted) return;
      for (final key in ['cep', 'street', 'neighborhood', 'city', 'state']) {
        _controllers[key]!.text = address.toMap()[key] as String;
      }
    } on AddressFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível buscar o endereço. Preencha manualmente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Widget _field(String key, String label, int limit, {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          key: Key('address-$key'),
          controller: _controllers[key],
          enabled:
              widget.enabled &&
              (!_busy || key == 'number' || key == 'complement'),
          decoration: InputDecoration(labelText: label, counterText: ''),
          maxLength: limit,
          textCapitalization: key == 'state'
              ? TextCapitalization.characters
              : TextCapitalization.words,
          textInputAction: TextInputAction.next,
          keyboardType: numeric
              ? TextInputType.number
              : TextInputType.streetAddress,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.digitsOnly]
              : key == 'state'
              ? [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))]
              : null,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (key == 'cep' && text.isNotEmpty && text.length != 8) {
              return 'Informe 8 dígitos ou deixe o CEP vazio.';
            }
            if (key == 'state' && text.isNotEmpty && text.length != 2) {
              return 'Informe a UF com duas letras.';
            }
            return null;
          },
        ),
      );
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const Key('address-section'),
    title: const Text('Endereço (opcional)'),
    initiallyExpanded: widget.initialValue != null,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(top: 16),
    maintainState: true,
    children: [
      _field('cep', 'CEP', 8, numeric: true),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('lookup-cep'),
          onPressed: widget.enabled && !_busy ? _lookup : null,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search, size: 18),
          label: Text(_busy ? 'Buscando…' : 'Buscar endereço'),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        InlineMessage(message: _error!),
      ],
      const SizedBox(height: 16),
      _field('street', 'Logradouro', 160),
      _field('number', 'Número', 20),
      _field('complement', 'Complemento', 160),
      _field('neighborhood', 'Bairro', 100),
      _field('city', 'Cidade', 100),
      _field('state', 'UF', 2),
    ],
  );
}
