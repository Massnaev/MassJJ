import 'dart:io';

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
                  child: NavigationBar(
                    selectedIndex: _selectedIndex,
                    destinations: _destinations,
                    onDestinationSelected: (value) =>
                        setState(() => _selectedIndex = value),
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
    final compact = MediaQuery.sizeOf(context).width < 820;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 32,
            compact ? 12 : 24,
            compact ? 16 : 32,
            compact ? 8 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: compact
                              ? Theme.of(context).textTheme.headlineSmall
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
              SizedBox(height: compact ? 12 : 22),
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
          const SizedBox(height: 10),
          if (widget.controller.contacts.isNotEmpty) ...[
            _NearbyStrip(
              controller: widget.controller,
              onOpen: widget.onOpen,
              onAddContact: widget.onAddContact,
            ),
            const SizedBox(height: 8),
          ],
          _TransportBanner(controller: widget.controller),
          const SizedBox(height: 6),
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
                    separatorBuilder: (_, _) => const SizedBox.shrink(),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final last = widget.controller.lastMessageFor(
                        contact.userId,
                      );
                      return _ChatListTile(
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

class _ContactsPage extends StatefulWidget {
  const _ContactsPage({
    required this.controller,
    required this.onOpen,
    required this.onAddContact,
  });

  final AppController controller;
  final ValueChanged<Contact> onOpen;
  final VoidCallback onAddContact;

  @override
  State<_ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<_ContactsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final contacts = widget.controller.contacts
        .where((contact) => contact.displayName.toLowerCase().contains(query))
        .toList();
    return _PageFrame(
      title: 'Контакты',
      subtitle: widget.controller.contacts.isEmpty
          ? 'Никого не добавлено'
          : 'Контактов: ${widget.controller.contacts.length}',
      action: IconButton(
        onPressed: widget.onAddContact,
        tooltip: 'Добавить контакт',
        icon: const Icon(Icons.person_add_alt_1_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Поиск контактов',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.accent,
            ),
            title: const Text(
              'Добавить по приглашению',
              style: TextStyle(
                color: AppColors.accentDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.faint,
            ),
            onTap: widget.onAddContact,
          ),
          Container(
            color: AppColors.interactive,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Text(
              'По имени · ключи проверяются локально',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: widget.controller.contacts.isEmpty
                ? const _EmptyState(
                    icon: Icons.qr_code_2,
                    title: 'Контактов пока нет',
                    body:
                        'Ваш QR-код находится в профиле. Добавьте контакт камерой или текстовым приглашением.',
                  )
                : contacts.isEmpty
                ? const _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Контакт не найден',
                    body: 'Попробуйте другое имя.',
                  )
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const SizedBox.shrink(),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return _ContactTile(
                        contact: contact,
                        trailing:
                            widget.controller.isContactNearby(contact.userId)
                            ? 'в сети · рядом'
                            : 'ключ ${contact.fingerprint}',
                        online: widget.controller.isContactNearby(
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

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.controller});

  final AppController controller;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _showRecovery = false;
  bool _showInvite = false;

  @override
  Widget build(BuildContext context) {
    final identity = widget.controller.identity;
    return ColoredBox(
      color: AppColors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ProfileHero(
            name: identity.displayName,
            onInvite: () => _copy(
              context,
              widget.controller.inviteCode,
              'Приглашение скопировано',
            ),
            onQr: () => setState(() => _showInvite = !_showInvite),
            onSecurity: () => setState(() => _showRecovery = !_showRecovery),
          ),
          _ProfileInfoRow(
            title: 'Локальный ID',
            value: identity.userId,
            icon: Icons.alternate_email_rounded,
            monospace: true,
          ),
          _ProfileInfoRow(
            title: 'Отпечаток ключа',
            value: identity.fingerprint,
            icon: Icons.fingerprint_rounded,
            monospace: true,
          ),
          _ProfileInfoRow(
            title: 'Хранилище',
            value: 'Ключи находятся только на этом устройстве',
            icon: Icons.phone_android_rounded,
          ),
          _ProfileInfoRow(
            title: 'Маршрут сообщений',
            value: widget.controller.nearbyPeerCount > 0
                ? 'LAN активен · relay как резерв'
                : widget.controller.relayReady
                ? 'Relay подключён'
                : 'Зашифрованная локальная очередь',
            icon: Icons.route_rounded,
          ),
          if (_showInvite)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: InviteCodePanel(
                inviteCode: widget.controller.inviteCode,
                onCopy: () => _copy(
                  context,
                  widget.controller.inviteCode,
                  'Код приглашения скопирован',
                ),
              ),
            ),
          if (_showRecovery)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Код восстановления',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Не отправляйте этот код другим людям.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      identity.recoveryCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _copy(
                        context,
                        identity.recoveryCode,
                        'Код восстановления скопирован',
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Копировать'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.onInvite,
    required this.onQr,
    required this.onSecurity,
  });

  final String name;
  final VoidCallback onInvite;
  final VoidCallback onQr;
  final VoidCallback onSecurity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF36AEDD), Color(0xFF6C72D9)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -30,
            top: 40,
            child: _HeroOrb(size: 120, opacity: 0.08),
          ),
          const Positioned(
            right: -24,
            top: -20,
            child: _HeroOrb(size: 150, opacity: 0.10),
          ),
          Positioned.fill(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      Spacer(),
                      Text(
                        'MASSJJ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: Color(0xFFBDF7D4), size: 7),
                    SizedBox(width: 5),
                    Text(
                      'локальная личность',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 62,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _ProfileAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Пригласить',
                        onTap: onInvite,
                      ),
                      _ProfileAction(
                        icon: Icons.qr_code_2_rounded,
                        label: 'QR-код',
                        onTap: onQr,
                      ),
                      _ProfileAction(
                        icon: Icons.security_rounded,
                        label: 'Безопасность',
                        onTap: onSecurity,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.title,
    required this.value,
    required this.icon,
    this.monospace = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    value,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontFamily: monospace ? 'monospace' : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  alignment: Alignment.center,
                  child: icon != null
                      ? Icon(icon, size: 20, color: AppColors.accent)
                      : Text(
                          initial!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
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

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
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
    final avatarColor = _avatarColor(contact.displayName);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: avatarColor,
                    foregroundColor: Colors.white,
                    child: Text(
                      contact.displayName.characters.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (nearby)
                    Positioned(
                      right: -1,
                      bottom: 1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 9),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.line, width: 0.7),
                    ),
                  ),
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
                                fontSize: 15,
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
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message?.body ?? 'Новый контакт',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _MessageStatusMark(message: message),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        ? 'Прямое соединение по Wi-Fi'
        : controller.relayReady
        ? 'Пакеты отправляются и принимаются'
        : controller.relayConfigured
        ? 'Сообщения дождутся подключения'
        : controller.nearbyReady
        ? 'Ищем устройства в локальной сети'
        : controller.nearbyError != null
        ? 'Локальная сеть недоступна · перезапустите приложение'
        : 'Сообщения сохраняются на устройстве';
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              nearby > 0
                  ? Icons.wifi_tethering_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
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
    this.online = false,
  });

  final Contact contact;
  final String trailing;
  final VoidCallback onTap;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: ListTile(
        minTileHeight: 62,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: AppColors.accentDeep,
              foregroundColor: Colors.white,
              child: Text(contact.displayName.characters.first.toUpperCase()),
            ),
            if (online)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          contact.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          trailing,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: online ? AppColors.success : AppColors.muted,
            fontSize: 12,
          ),
        ),
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
                color: AppColors.accentPale,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 28, color: AppColors.accent),
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
