import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/identity/anonymous_identity.dart';
import '../core/messaging/chat_message.dart';

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
  bool _sending = false;

  @override
  void dispose() {
    _composer.dispose();
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contact.displayName),
                const Text('E2EE · ожидает транспорт', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const _ChatEmpty()
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return _MessageBubble(message: messages[messages.length - index - 1]);
                          },
                        ),
                ),
                _Composer(
                  controller: _composer,
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
        const SnackBar(content: Text('Не удалось зашифровать сообщение.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 44),
            SizedBox(height: 12),
            Text('Сообщения шифруются до помещения в очередь.', textAlign: TextAlign.center),
          ],
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
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(15, 11, 15, 9),
        decoration: BoxDecoration(
          color: outgoing ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(outgoing ? 18 : 5),
            bottomRight: Radius.circular(outgoing ? 5 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(message.body)),
            const SizedBox(height: 5),
            Text(
              _statusLabel(message.status),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(MessageStatus status) => switch (status) {
        MessageStatus.encrypting => 'Шифруется…',
        MessageStatus.queued => 'Зашифровано · в очереди',
        MessageStatus.sent => 'Отправлено',
        MessageStatus.delivered => 'Доставлено',
        MessageStatus.failed => 'Ошибка',
      };
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Сообщение',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Зашифровать и отправить',
            ),
          ],
        ),
      ),
    );
  }
}
