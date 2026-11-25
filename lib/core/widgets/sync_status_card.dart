import 'package:flutter/material.dart';
import '../../models/activity_sync_state.dart';
import '../theme/app_theme.dart';

class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key, required this.state, required this.onRetry});
  final ActivitySyncState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = !state.hasConnection
        ? 'Sem conexão. Alterações salvas neste aparelho.'
        : state.lastError ??
              (state.synchronizing
                  ? 'Sincronizando suas alterações…'
                  : state.pendingCount > 0
                  ? '${state.pendingCount} alterações aguardando envio.'
                  : 'Nenhuma alteração pendente.');
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text,
                key: const Key('sync-status'),
                style: const TextStyle(color: AppColors.muted),
              ),
              if (state.pendingCount > 0 &&
                  (state.lastError != null || !state.hasConnection)) ...[
                const SizedBox(height: 4),
                Text(
                  '${state.pendingCount} alterações aguardando envio.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              if (state.hasConnection &&
                  !state.synchronizing &&
                  (state.pendingCount > 0 || state.lastError != null))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('retry-sync'),
                    onPressed: onRetry,
                    child: const Text('Tentar sincronizar'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
