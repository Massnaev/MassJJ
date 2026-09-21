import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'theme.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.raised,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                      const SizedBox(width: 30),
                      Expanded(child: explanation),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: qr),
                      const SizedBox(height: 20),
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
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: QrImageView(
            key: const ValueKey('invite-qr'),
            data: code,
            size: 228,
            padding: const EdgeInsets.all(10),
            backgroundColor: Colors.white,
            semanticsLabel: 'QR-код приглашения в MassJJ',
            errorStateBuilder: (context, _) => const ColoredBox(
              color: Colors.white,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Не удалось построить QR-код',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.canvas),
                  ),
                ),
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
        Text(
          'Моё приглашение',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Покажите QR человеку рядом или отправьте код через доверенный канал.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.interactive,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            inviteCode,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.link_rounded, size: 19),
          label: const Text('Копировать код'),
        ),
        const SizedBox(height: 8),
        Text(
          'QR содержит только публичный ключ и право отправлять вам сообщения. Резервного кода в нём нет.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}
