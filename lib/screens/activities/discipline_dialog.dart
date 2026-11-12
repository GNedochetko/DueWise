import 'package:flutter/material.dart';
import '../../controllers/activity_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/inline_message.dart';
import '../../repositories/activity_repository.dart';

class DisciplineDialog extends StatefulWidget {
  const DisciplineDialog({super.key, required this.controller});
  final ActivityController controller;
  @override
  State<DisciplineDialog> createState() => _DisciplineDialogState();
}

class _DisciplineDialogState extends State<DisciplineDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  static const _colors = [
    AppColors.primary,
    Color(0xFF34785E),
    Color(0xFF6D5A94),
    Color(0xFF946B22),
  ];
  var _color = AppColors.primary;
  var _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final discipline = await widget.controller.createDiscipline(
        _name.text,
        _color.toARGB32(),
      );
      if (mounted) Navigator.of(context).pop(discipline);
    } on ActivityFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Não foi possível salvar a disciplina.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Nova disciplina'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('discipline-name'),
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Nome'),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o nome da disciplina.'
                    : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              const Text('Cor'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _colors.length; i++)
                    IconButton(
                      tooltip: ['Azul', 'Verde', 'Roxo', 'Ocre'][i],
                      onPressed: _busy
                          ? null
                          : () => setState(() => _color = _colors[i]),
                      isSelected: _color == _colors[i],
                      style: IconButton.styleFrom(
                        backgroundColor: _colors[i].withValues(alpha: .12),
                      ),
                      icon: Icon(
                        _color == _colors[i]
                            ? Icons.check_circle
                            : Icons.circle,
                        color: _colors[i],
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                InlineMessage(message: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('save-discipline'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Salvando…' : 'Salvar'),
        ),
      ],
    ),
  );
}
