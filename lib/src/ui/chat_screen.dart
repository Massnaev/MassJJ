import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/crypto/crypto_engine.dart';
import '../core/identity/anonymous_identity.dart';
import '../core/messaging/chat_message.dart';
import 'theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.controller,
    required this.contact,
    super.key,
  });

  final AppController controller;
  final Contact contact;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final messages = widget.controller.messagesFor(widget.contact.userId);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accentDeep,
                  child: Text(
                    widget.contact.displayName.characters.first.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _connectionLabel(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              widget.controller.isContactNearby(
                                widget.contact.userId,
                              )
                              ? AppColors.success
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _showSecurityDetails,
                icon: const Icon(Icons.verified_user_outlined, size: 20),
                tooltip: 'Защита диалога',
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _EncryptionPill(label: widget.controller.cryptoInfo.label),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ChatBackdropPainter(),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: messages.isEmpty
                                ? _ChatEmpty(
                                    contactName: widget.contact.displayName,
                                    cryptoInfo: widget.controller.cryptoInfo,
                                  )
                                : ListView.builder(
                                    reverse: true,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      14,
                                    ),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      return _MessageBubble(
                                        message:
                                            messages[messages.length -
                                                index -
                                                1],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _Composer(
                  controller: _composer,
                  focusNode: _composerFocus,
                  enabled: !_sending,
                  onSend: _send,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _connectionLabel() {
    final transport = widget.controller.isContactNearby(widget.contact.userId)
        ? 'рядом по Wi-Fi'
        : widget.controller.relayReady
        ? 'relay подключён'
        : 'локальная очередь';
    return '${widget.controller.cryptoInfo.label} · $transport';
  }

  Future<void> _showSecurityDetails() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SecurityDetails(
        contact: widget.contact,
        cryptoInfo: widget.controller.cryptoInfo,
      ),
    );
  }

  Future<void> _send() async {
    if (_composer.text.trim().isEmpty || _sending) return;
    final text = _composer.text;
    _composer.clear();
    setState(() => _sending = true);
    try {
      await widget.controller.sendMessage(widget.contact, text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сообщение не зашифровано. Проверьте данные контакта и повторите попытку.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _composerFocus.requestFocus();
      }
    }
  }
}

class _ChatBackdropPainter extends CustomPainter {
  const _ChatBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppColors.accent.withValues(alpha: 0.055);
    final ring = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 24.0; y < size.height; y += 68) {
      final row = (y / 68).floor();
      for (var x = row.isEven ? 30.0 : 64.0; x < size.width; x += 94) {
        canvas.drawCircle(Offset(x, y), 2, dot);
        if ((x + y).round().isEven) {
          canvas.drawCircle(Offset(x + 18, y + 18), 8, ring);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackdropPainter oldDelegate) => false;
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty({required this.contactName, required this.cryptoInfo});

  final String contactName;
  final CryptoEngineInfo cryptoInfo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentPale,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Диалог с $contactName',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Сообщение шифруется на этом устройстве до попадания в очередь или на relay.',
                textAlign: TextAlign.center,
              ),
              if (!cryptoInfo.supportsForwardSecrecy) ...[
                const SizedBox(height: 14),
                Text(
                  'Текущий MVP ещё не использует Double Ratchet и не обеспечивает прямую секретность.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final outgoing = message.direction == MessageDirection.outgoing;
    final bubbleColor = outgoing ? AppColors.accentDeep : AppColors.interactive;
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 600 ? 330 : 540,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: outgoing ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(outgoing ? 16 : 4),
            bottomRight: Radius.circular(outgoing ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                message.body,
                style: TextStyle(
                  color: outgoing ? Colors.white : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 5),
            _MessageMeta(message: message),
          ],
        ),
      ),
    );
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt.toLocal();
    final status = _statusPresentation(message.status);
    final error = message.status == MessageStatus.failed;
    final outgoing = message.direction == MessageDirection.outgoing;
    final metaColor = outgoing
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: metaColor),
        ),
        if (message.direction == MessageDirection.outgoing) ...[
          const SizedBox(width: 6),
          Icon(
            status.icon,
            size: 14,
            color: error && !outgoing ? AppColors.error : metaColor,
          ),
          const SizedBox(width: 3),
          Text(
            status.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: error && !outgoing ? AppColors.error : metaColor,
            ),
          ),
        ],
      ],
    );
  }

  ({IconData icon, String label}) _statusPresentation(MessageStatus status) {
    return switch (status) {
      MessageStatus.encrypting => (
        icon: Icons.lock_clock_outlined,
        label: 'шифруется',
      ),
      MessageStatus.queued => (
        icon: Icons.schedule_outlined,
        label: 'в очереди',
      ),
      MessageStatus.sent => (icon: Icons.check, label: 'отправлено'),
      MessageStatus.delivered => (icon: Icons.done_all, label: 'доставлено'),
      MessageStatus.failed => (icon: Icons.error_outline, label: 'ошибка'),
    };
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      shape: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: enabled ? () {} : null,
                  tooltip: 'Вложения появятся позже',
                  icon: const Icon(Icons.add_rounded, size: 21),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Сообщение',
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final canSend = enabled && value.text.trim().isNotEmpty;
                    return IconButton.filled(
                      onPressed: canSend ? onSend : null,
                      icon: enabled
                          ? const Icon(Icons.send_rounded, size: 19)
                          : const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                      tooltip: 'Зашифровать и отправить',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EncryptionPill extends StatelessWidget {
  const _EncryptionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.accentPale,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: AppColors.accent,
            ),
            const SizedBox(width: 7),
            Text(
              'Зашифровано · $label',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.accentDeep),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityDetails extends StatelessWidget {
  const _SecurityDetails({required this.contact, required this.cryptoInfo});

  final Contact contact;
  final CryptoEngineInfo cryptoInfo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Защита этого диалога',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Криптосхема: ${cryptoInfo.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  cryptoInfo.supportsForwardSecrecy
                      ? 'Для диалога включена прямая секретность.'
                      : 'В этой MVP-сборке Double Ratchet ещё не подключён, поэтому прямой секретности пока нет.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Отпечаток контакта',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  contact.fingerprint,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Сравните этот отпечаток при личной встрече или по другому доверенному каналу, чтобы исключить подмену контакта.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
