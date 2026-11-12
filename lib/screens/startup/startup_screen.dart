import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 56),
                  const SizedBox(height: 40),
                  if (!hasError)
                    const CircularProgressIndicator()
                  else ...[
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
