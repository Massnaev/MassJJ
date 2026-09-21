import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../core/identity/anonymous_identity.dart';
import '../core/messaging/chat_message.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
import 'invite_code_panel.dart';
import 'theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: Icon(Icons.chat_bubble_rounded),
      label: 'Чаты',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: 'Контакты',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Профиль',
    ),
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
                bottomNavigationBar: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: NavigationBar(
                      selectedIndex: _selectedIndex,
                      destinations: _destinations,
                      onDestinationSelected: (value) =>
                          setState(() => _selectedIndex = value),
                    ),
                  ),
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
    final contact = await Navigator.of(context).push<Contact>(
      MaterialPageRoute<Contact>(
        builder: (_) => AddContactScreen(
          cameraEnabled: Platform.isAndroid || Platform.isIOS,
          addContact: widget.controller.addContact,
        ),
      ),
    );
    if (!mounted || contact == null) return;
    _openChat(contact);
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final showMark = MediaQuery.sizeOf(context).width < 820;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            showMark ? 20 : 32,
            24,
            showMark ? 20 : 32,
            20,
          ),
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
                          style: showMark
                              ? Theme.of(context).textTheme.headlineMedium
                              : Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle),
                      ],
                    ),
                  ),
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              ),
              const SizedBox(height: 22),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsPage extends StatefulWidget {
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
  State<_ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<_ChatsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final contacts = widget.controller.contacts.where((contact) {
      if (query.isEmpty) return true;
      final last = widget.controller.lastMessageFor(contact.userId)?.body ?? '';
      return contact.displayName.toLowerCase().contains(query) ||
          last.toLowerCase().contains(query);
    }).toList();
    return _PageFrame(
      title: 'Чаты',
      subtitle: 'Защищённая связь',
      action: IconButton(
        onPressed: widget.onAddContact,
        tooltip: 'Добавить контакт',
        icon: const Icon(Icons.add_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Поиск по чатам',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.muted,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.controller.contacts.isNotEmpty) ...[
            _NearbyStrip(
              controller: widget.controller,
              onOpen: widget.onOpen,
              onAddContact: widget.onAddContact,
            ),
            const SizedBox(height: 14),
          ],
          _TransportBanner(controller: widget.controller),
          const SizedBox(height: 16),
          Expanded(
            child: widget.controller.contacts.isEmpty
                ? _EmptyState(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Добавьте первый контакт',
                    body:
                        'Вставьте код приглашения с другого устройства. После этого можно сразу начать зашифрованный диалог.',
                    primaryLabel: 'Добавить контакт',
                    onPrimary: widget.onAddContact,
                    secondaryLabel: 'Показать мой код',
                    onSecondary: widget.onShowProfile,
                  )
                : contacts.isEmpty
                ? const _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Ничего не найдено',
                    body: 'Попробуйте другое имя или текст сообщения.',
                  )
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final last = widget.controller.lastMessageFor(
                        contact.userId,
                      );
                      return _ChatGlassTile(
                        contact: contact,
                        message: last,
                        nearby: widget.controller.isContactNearby(
                          contact.userId,
                        ),
                        onTap: () => widget.onOpen(contact),
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
      subtitle: controller.contacts.isEmpty
          ? 'Никого не добавлено'
          : 'Контактов: ${controller.contacts.length}',
      action: IconButton(
        onPressed: onAddContact,
        tooltip: 'Добавить контакт',
        icon: const Icon(Icons.add_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
      title: 'Профиль',
      subtitle: 'Локальная личность',
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

class _NearbyStrip extends StatelessWidget {
  const _NearbyStrip({
    required this.controller,
    required this.onOpen,
    required this.onAddContact,
  });

  final AppController controller;
  final ValueChanged<Contact> onOpen;
  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    final contacts = controller.contacts.take(4).toList();
    return SizedBox(
      height: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'БЫСТРЫЙ ДОСТУП',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontSize: 10,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 9),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: contacts.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == contacts.length) {
                  return _QuickContact(
                    label: 'Добавить',
                    icon: Icons.add_rounded,
                    onTap: onAddContact,
                  );
                }
                final contact = contacts[index];
                return _QuickContact(
                  label: contact.displayName.split(' ').first,
                  initial: contact.displayName.characters.first.toUpperCase(),
                  online: controller.isContactNearby(contact.userId),
                  color: _avatarColor(index),
                  onTap: () => onOpen(contact),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _avatarColor(int index) => const [
    AppColors.accentDeep,
    Color(0xFF2E708F),
    Color(0xFF9B5E49),
    Color(0xFF3F7657),
  ][index % 4];
}

class _QuickContact extends StatelessWidget {
  const _QuickContact({
    required this.label,
    required this.onTap,
    this.initial,
    this.icon,
    this.online = false,
    this.color = AppColors.interactive,
  });

  final String label;
  final VoidCallback onTap;
  final String? initial;
  final IconData? icon;
  final bool online;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.line),
                  ),
                  alignment: Alignment.center,
                  child: icon != null
                      ? Icon(icon, size: 20, color: AppColors.muted)
                      : Text(
                          initial!,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
                if (online)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.canvas, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatGlassTile extends StatelessWidget {
  const _ChatGlassTile({
    required this.contact,
    required this.message,
    required this.nearby,
    required this.onTap,
  });

  final Contact contact;
  final ChatMessage? message;
  final bool nearby;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = message?.status == MessageStatus.queued
        ? AppColors.queued
        : nearby
        ? AppColors.success
        : AppColors.accentSoft;
    final avatarColor = _avatarColor(contact.displayName);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.24),
            AppColors.line.withValues(alpha: 0.70),
          ],
          stops: const [0, 0.42, 1],
        ),
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Material(
              color: AppColors.raised.withValues(alpha: 0.90),
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: avatarColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              contact.displayName.characters.first
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (nearby)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.raised,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    contact.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (message != null)
                                  Text(
                                    _time(message!.createdAt),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.faint,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    message?.body ?? 'Новый контакт',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _MessageStatusMark(message: message),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Color _avatarColor(String value) {
    final index = value.codeUnits.fold<int>(0, (sum, item) => sum + item) % 4;
    return const [
      AppColors.accentDeep,
      Color(0xFF2E708F),
      Color(0xFF9B5E49),
      Color(0xFF3F7657),
    ][index];
  }
}

class _MessageStatusMark extends StatelessWidget {
  const _MessageStatusMark({required this.message});

  final ChatMessage? message;

  @override
  Widget build(BuildContext context) {
    final value = message;
    if (value == null || value.direction == MessageDirection.incoming) {
      return const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: AppColors.faint,
      );
    }
    final (icon, color) = switch (value.status) {
      MessageStatus.encrypting => (
        Icons.lock_clock_outlined,
        AppColors.accentSoft,
      ),
      MessageStatus.queued => (Icons.schedule_rounded, AppColors.queued),
      MessageStatus.sent => (Icons.check_rounded, AppColors.accentSoft),
      MessageStatus.delivered => (Icons.done_all_rounded, AppColors.accentSoft),
      MessageStatus.failed => (Icons.error_outline_rounded, AppColors.error),
    };
    return Icon(icon, size: 17, color: color);
  }
}

class _TransportBanner extends StatelessWidget {
  const _TransportBanner({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final nearby = controller.nearbyPeerCount;
    final color = nearby > 0 || controller.relayReady
        ? AppColors.success
        : AppColors.queued;
    final title = nearby > 0
        ? nearby == 1
              ? 'Одно устройство рядом'
              : 'Устройств рядом: $nearby'
        : controller.relayReady
        ? 'Relay подключён'
        : 'Локальная очередь';
    final subtitle = nearby > 0
        ? 'Сообщения контактам рядом идут напрямую по локальной Wi-Fi-сети.'
        : controller.relayReady
        ? 'Зашифрованные пакеты отправляются и принимаются.'
        : controller.relayConfigured
        ? 'Relay недоступен; сообщения дождутся подключения.'
        : controller.nearbyReady
        ? 'Ищем знакомые устройства в локальной сети.'
        : 'Пакеты шифруются и сохраняются до появления транспорта.';
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
            Icon(
              nearby > 0
                  ? Icons.wifi_tethering_rounded
                  : Icons.lock_outline_rounded,
              size: 20,
              color: color,
            ),
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
    return Material(
      color: AppColors.canvas,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        leading: CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.accentDeep,
          child: Text(contact.displayName.characters.first.toUpperCase()),
        ),
        title: Text(
          contact.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.faint,
        ),
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1D1830),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 28, color: AppColors.accentSoft),
            ),
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
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        Icons.chat_bubble_outline_rounded,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
