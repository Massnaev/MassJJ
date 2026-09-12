import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InviteCodePanel extends StatelessWidget {
  const InviteCodePanel({
    required this.inviteCode,
    required this.onCopy,
    super.key,
  });

  final String inviteCode;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            final qr = _InviteQr(code: inviteCode);
            final explanation = _InviteExplanation(
              inviteCode: inviteCode,
              onCopy: onCopy,
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      qr,
                      const SizedBox(width: 28),
                      Expanded(child: explanation),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: qr),
                      const SizedBox(height: 22),
                      explanation,
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _InviteQr extends StatelessWidget {
  const _InviteQr({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: QrImageView(
        key: const ValueKey('invite-qr'),
        data: code,
        size: 236,
        padding: const EdgeInsets.all(14),
        backgroundColor: Colors.white,
        semanticsLabel: 'QR-код приглашения в P2P Messenger',
        errorStateBuilder: (context, _) => const ColoredBox(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Не удалось построить QR-код',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteExplanation extends StatelessWidget {
  const _InviteExplanation({required this.inviteCode, required this.onCopy});

  final String inviteCode;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Приглашение', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Покажите QR-код человеку рядом или отправьте текстовый код через доверенный канал.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            inviteCode,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Копировать код'),
        ),
        const SizedBox(height: 8),
        Text(
          'QR содержит только публичный ключ и право отправлять вам сообщения. Резервного кода в нём нет.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
