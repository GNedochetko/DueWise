import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({
    super.key,
    this.hasError = false,
    this.configurationMissing = false,
    this.onRetry,
  });
  final bool hasError;
  final bool configurationMissing;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: !hasError
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/branding/monk_splash.webp',
                      width: 288,
                      height: 288,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, 124),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Iniciando DueWise',
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : _errorContent(context),
      ),
    );
  }

  Widget _errorContent(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/monk_splash.webp',
              width: 192,
              height: 192,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 8),
            Text(
              configurationMissing
                  ? 'Configuração inicial pendente'
                  : 'Não foi possível iniciar o DueWise',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              configurationMissing
                  ? 'Conclua a configuração do aplicativo antes de entrar.'
                  : 'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    ),
  );
}
