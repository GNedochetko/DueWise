import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/inline_message.dart';
import '../../repositories/auth_repository.dart';

enum _AuthMode { login, register, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.repository});
  final AuthRepository repository;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _formKey = GlobalKey<FormState>();
  var _mode = _AuthMode.login;
  var _busy = false;
  var _hidePassword = true;
  var _hideConfirmation = true;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _changeMode(_AuthMode mode) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = mode;
      _error = null;
      _message = null;
      _formKey = GlobalKey<FormState>();
      _password.clear();
      _confirmation.clear();
      _hidePassword = true;
      _hideConfirmation = true;
    });
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      switch (_mode) {
        case _AuthMode.login:
          await widget.repository.signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
        case _AuthMode.register:
          await widget.repository.register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
        case _AuthMode.reset:
          await widget.repository.resetPassword(_email.text.trim());
          if (mounted) {
            setState(
              () => _message =
                  'Se houver uma conta com este e-mail, você receberá as instruções para redefinir sua senha.',
            );
          }
      }
      if (_mode != _AuthMode.reset) TextInput.finishAutofillContext();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível concluir a operação. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _AuthMode.register;
    final isReset = _mode == _AuthMode.reset;
    final title = switch (_mode) {
      _AuthMode.login => 'Entrar',
      _AuthMode.register => 'Criar conta',
      _AuthMode.reset => 'Recuperar senha',
    };
    final subtitle = switch (_mode) {
      _AuthMode.login => 'Acesse sua agenda acadêmica.',
      _AuthMode.register => 'Preencha seus dados para começar.',
      _AuthMode.reset =>
        'Informe seu e-mail para receber as instruções de recuperação.',
    };

    return PopScope(
      canPop: _mode == _AuthMode.login && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && _mode != _AuthMode.login) {
          _changeMode(_AuthMode.login);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      minHeight: (constraints.maxHeight - 48).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: BrandLogo(),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 28),
                            if (_error != null) ...[
                              InlineMessage(message: _error!),
                              const SizedBox(height: 20),
                            ],
                            if (_message != null) ...[
                              InlineMessage(message: _message!, isError: false),
                              const SizedBox(height: 20),
                            ],
                            if (isRegister) ...[
                              TextFormField(
                                key: const Key('name'),
                                controller: _name,
                                enabled: !_busy,
                                decoration: const InputDecoration(
                                  labelText: 'Nome completo',
                                ),
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                validator: Validators.name,
                              ),
                              const SizedBox(height: 18),
                            ],
                            TextFormField(
                              key: const Key('email'),
                              controller: _email,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: isReset
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              enableSuggestions: false,
                              validator: Validators.email,
                              onFieldSubmitted: isReset
                                  ? (_) => _submit()
                                  : null,
                            ),
                            if (!isReset) ...[
                              const SizedBox(height: 18),
                              TextFormField(
                                key: const Key('password'),
                                controller: _password,
                                enabled: !_busy,
                                obscureText: _hidePassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: isRegister
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                autofillHints: [
                                  isRegister
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  helperText: isRegister
                                      ? 'Use pelo menos 8 caracteres.'
                                      : null,
                                  suffixIcon: IconButton(
                                    tooltip: _hidePassword
                                        ? 'Mostrar senha'
                                        : 'Ocultar senha',
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () =>
                                                _hidePassword = !_hidePassword,
                                          ),
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: isRegister
                                    ? Validators.newPassword
                                    : Validators.loginPassword,
                                onFieldSubmitted: isRegister
                                    ? null
                                    : (_) => _submit(),
                              ),
                            ],
                            if (isRegister) ...[
                              const SizedBox(height: 18),
                              TextFormField(
                                key: const Key('confirmation'),
                                controller: _confirmation,
                                enabled: !_busy,
                                obscureText: _hideConfirmation,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Confirmar senha',
                                  suffixIcon: IconButton(
                                    tooltip: _hideConfirmation
                                        ? 'Mostrar confirmação de senha'
                                        : 'Ocultar confirmação de senha',
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _hideConfirmation =
                                                !_hideConfirmation,
                                          ),
                                    icon: Icon(
                                      _hideConfirmation
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirme sua senha.';
                                  }
                                  return value != _password.text
                                      ? 'As senhas não coincidem.'
                                      : null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                            ],
                            if (_mode == _AuthMode.login)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  key: const Key('open-reset'),
                                  onPressed: _busy
                                      ? null
                                      : () => _changeMode(_AuthMode.reset),
                                  child: const Text('Esqueci minha senha'),
                                ),
                              ),
                            SizedBox(
                              height: _mode == _AuthMode.login ? 12 : 28,
                            ),
                            FilledButton(
                              key: const Key('auth-submit'),
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                        semanticsLabel: 'Aguarde',
                                      ),
                                    )
                                  : Text(isReset ? 'Enviar instruções' : title),
                            ),
                            const SizedBox(height: 18),
                            if (_mode == _AuthMode.login)
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Ainda não tem uma conta?',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                  TextButton(
                                    key: const Key('open-register'),
                                    onPressed: _busy
                                        ? null
                                        : () => _changeMode(_AuthMode.register),
                                    child: const Text('Cadastre-se'),
                                  ),
                                ],
                              )
                            else
                              TextButton(
                                key: const Key('back-login'),
                                onPressed: _busy
                                    ? null
                                    : () => _changeMode(_AuthMode.login),
                                child: const Text('Voltar para entrar'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
