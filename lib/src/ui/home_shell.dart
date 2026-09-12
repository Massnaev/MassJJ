import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../core/identity/anonymous_identity.dart';
import 'chat_screen.dart';
import 'invite_code_panel.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Чаты'),
    NavigationDestination(icon: Icon(Icons.people_outline), label: 'Контакты'),
    NavigationDestination(icon: Icon(Icons.key_outlined), label: 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final body = IndexedStack(
              index: _selectedIndex,
              children: [
                _ChatsPage(
                  controller: widget.controller,
                  onOpen: _openChat,
                  onAddContact: _showAddContact,
                  onShowProfile: () => setState(() => _selectedIndex = 2),
                ),
                _ContactsPage(
                  controller: widget.controller,
                  onOpen: _openChat,
                  onAddContact: _showAddContact,
                ),
                _ProfilePage(controller: widget.controller),
              ],
            );

            if (!wide) {
              return Scaffold(
                body: SafeArea(child: body),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _selectedIndex,
                  destinations: _destinations,
                  onDestinationSelected: (value) =>
                      setState(() => _selectedIndex = value),
                ),
              );
            }

            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      labelType: NavigationRailLabelType.all,
                      leading: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: _Mark(),
                      ),
                      destinations: [
                        for (final destination in _destinations)
                          NavigationRailDestination(
                            icon: destination.icon,
                            label: Text(destination.label),
                          ),
                      ],
                      onDestinationSelected: (value) {
                        setState(() => _selectedIndex = value);
                      },
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openChat(Contact contact) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(controller: widget.controller, contact: contact),
      ),
    );
  }

  Future<void> _showAddContact() async {
    final textController = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить контакт'),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: textController,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Код приглашения',
                hintText: 'p2p1.…',
                errorText: error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final contact = await widget.controller.addContact(
                    textController.text,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  _openChat(contact);
                } on FormatException catch (exception) {
                  setDialogState(() => error = exception.message.toString());
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    textController.dispose();
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final showMark = MediaQuery.sizeOf(context).width < 820;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showMark) ...[const _Mark(), const SizedBox(width: 14)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsPage extends StatelessWidget {
  const _ChatsPage({
    required this.controller,
    required this.onOpen,
    required this.onAddContact,
    required this.onShowProfile,
  });

  final AppController controller;
  final ValueChanged<Contact> onOpen;
  final VoidCallback onAddContact;
  final VoidCallback onShowProfile;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Сообщения',
      subtitle: 'Личность создана локально · телефон и почта не нужны',
      child: Column(
        children: [
          _TransportBanner(controller: controller),
          const SizedBox(height: 16),
          Expanded(
            child: controller.contacts.isEmpty
                ? _EmptyState(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Добавьте первый контакт',
                    body:
                        'Вставьте код приглашения с другого устройства. После этого можно сразу начать зашифрованный диалог.',
                    primaryLabel: 'Добавить контакт',
                    onPrimary: onAddContact,
                    secondaryLabel: 'Показать мой код',
                    onSecondary: onShowProfile,
                  )
                : ListView.separated(
                    itemCount: controller.contacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = controller.contacts[index];
                      final last = controller.lastMessageFor(contact.userId);
                      return _ContactTile(
                        contact: contact,
                        trailing: last == null ? 'Новый контакт' : last.body,
                        onTap: () => onOpen(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactsPage extends StatelessWidget {
  const _ContactsPage({
    required this.controller,
    required this.onOpen,
    required this.onAddContact,
  });

  final AppController controller;
  final ValueChanged<Contact> onOpen;
  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Контакты',
      subtitle: 'Обменяйтесь кодами лично или через доверенный канал',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onAddContact,
            icon: const Icon(Icons.add),
            label: const Text('Добавить по коду'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: controller.contacts.isEmpty
                ? const _EmptyState(
                    icon: Icons.qr_code_2,
                    title: 'Контактов пока нет',
                    body:
                        'Ваш QR-код находится в профиле. Камерное сканирование добавим после подключения платформенных разрешений.',
                  )
                : ListView.separated(
                    itemCount: controller.contacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = controller.contacts[index];
                      return _ContactTile(
                        contact: contact,
                        trailing: contact.fingerprint,
                        onTap: () => onOpen(contact),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.controller});

  final AppController controller;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _showRecovery = false;

  @override
  Widget build(BuildContext context) {
    final identity = widget.controller.identity;
    return _PageFrame(
      title: 'Ваш профиль',
      subtitle: 'Псевдонимная личность хранится только на этом устройстве',
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  const Text('ID устройства'),
                  const SizedBox(height: 4),
                  SelectableText(
                    identity.userId,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 14),
                  const Text('Отпечаток ключа'),
                  const SizedBox(height: 4),
                  SelectableText(
                    identity.fingerprint,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          InviteCodePanel(
            inviteCode: widget.controller.inviteCode,
            onCopy: () => _copy(
              context,
              widget.controller.inviteCode,
              'Код приглашения скопирован',
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Код восстановления',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Любой, кто получит этот код, сможет восстановить вашу личность.',
                  ),
                  const SizedBox(height: 12),
                  if (_showRecovery)
                    SelectableText(
                      identity.recoveryCode,
                      style: const TextStyle(fontFamily: 'monospace'),
                    )
                  else
                    const Text('•••• •••• •••• ••••'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _showRecovery = !_showRecovery),
                    child: Text(_showRecovery ? 'Скрыть' : 'Показать'),
                  ),
                  if (_showRecovery) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _copy(
                        context,
                        identity.recoveryCode,
                        'Код восстановления скопирован',
                      ),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Копировать код восстановления'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(
    BuildContext context,
    String text,
    String confirmation,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(confirmation)));
  }
}

class _TransportBanner extends StatelessWidget {
  const _TransportBanner({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final color = controller.relayReady
        ? const Color(0xFF3F8061)
        : const Color(0xFFD58B36);
    final title = controller.relayReady
        ? 'Relay подключён'
        : 'Локальная очередь';
    final subtitle = controller.relayReady
        ? 'Зашифрованные пакеты отправляются и принимаются.'
        : controller.relayConfigured
        ? 'Relay недоступен; сообщения дождутся подключения.'
        : 'Пакеты шифруются и ждут настройки RELAY_URL.';
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.lock_outline),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.trailing,
    required this.onTap,
  });

  final Contact contact;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(contact.displayName.characters.first.toUpperCase()),
        ),
        title: Text(contact.displayName),
        subtitle: Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (primaryLabel != null && onPrimary != null) ...[
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onPrimary,
                icon: const Icon(Icons.add),
                label: Text(primaryLabel!),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 6),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        Icons.hub_outlined,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
