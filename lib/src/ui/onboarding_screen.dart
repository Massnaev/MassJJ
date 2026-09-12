import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/identity/anonymous_identity.dart';

enum _OnboardingStep { welcome, backup, restore }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onCreateIdentity,
    required this.onRestoreIdentity,
    required this.onReady,
    super.key,
  });

  final Future<AnonymousIdentity> Function() onCreateIdentity;
  final Future<AnonymousIdentity> Function(String code) onRestoreIdentity;
  final Future<void> Function() onReady;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _recoveryController = TextEditingController();
  _OnboardingStep _step = _OnboardingStep.welcome;
  AnonymousIdentity? _identity;
  String? _error;
  bool _savedRecoveryCode = false;
  bool _busy = false;

  @override
  void dispose() {
    _recoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            final content = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(child: _Introduction()),
                      const SizedBox(width: 48),
                      Expanded(child: Center(child: _stepContent())),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Introduction(compact: true),
                      const SizedBox(height: 32),
                      _stepContent(),
                    ],
                  );
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 48 : 24,
                vertical: wide ? 40 : 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: SizedBox(
                    height: wide ? constraints.maxHeight - 80 : null,
                    child: content,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _stepContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 470),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (_step) {
              _OnboardingStep.welcome => _welcome(),
              _OnboardingStep.backup => _backup(),
              _OnboardingStep.restore => _restore(),
            },
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Начнём', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Приложение создаст ключи прямо на устройстве. Имя, телефон и почта не потребуются.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('create-identity'),
          onPressed: _busy ? null : _createIdentity,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_moderator_outlined),
          label: const Text('Создать новую личность'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _step = _OnboardingStep.restore;
                  _error = null;
                }),
          icon: const Icon(Icons.settings_backup_restore),
          label: const Text('Восстановить по коду'),
        ),
        const SizedBox(height: 18),
        const _SecurityNote(
          icon: Icons.phonelink_lock_outlined,
          text: 'Секретный ключ не отправляется на relay-сервер.',
        ),
      ],
    );
  }

  Widget _backup() {
    final identity = _identity!;
    return Column(
      key: const ValueKey('backup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.key_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Сохраните код',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Это единственный способ вернуть эту личность после потери или замены устройства.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            identity.recoveryCode,
            key: const ValueKey('recovery-code'),
            style: const TextStyle(fontFamily: 'monospace', height: 1.45),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _copyRecoveryCode(identity.recoveryCode),
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Копировать код'),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          key: const ValueKey('confirm-backup'),
          value: _savedRecoveryCode,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Я сохранил код в безопасном месте'),
          subtitle: const Text('Не отправляйте его другим людям.'),
          onChanged: (value) {
            setState(() => _savedRecoveryCode = value ?? false);
          },
        ),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('finish-onboarding'),
          onPressed: !_savedRecoveryCode || _busy ? null : _finish,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Открыть мессенджер'),
        ),
      ],
    );
  }

  Widget _restore() {
    return Column(
      key: const ValueKey('restore'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Восстановление',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Вставьте резервный код, который начинается с p2pr1. Он будет сохранён в защищённом хранилище этого устройства.',
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('restore-code'),
          controller: _recoveryController,
          minLines: 4,
          maxLines: 7,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Код восстановления',
            hintText: 'p2pr1.…',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 14),
        FilledButton(
          key: const ValueKey('restore-identity'),
          onPressed: _busy ? null : _restoreIdentity,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Восстановить личность'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _step = _OnboardingStep.welcome;
                  _error = null;
                }),
          child: const Text('Назад'),
        ),
      ],
    );
  }

  Future<void> _createIdentity() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final identity = await widget.onCreateIdentity();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _step = _OnboardingStep.backup;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать локальную личность.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreIdentity() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onRestoreIdentity(_recoveryController.text);
      if (!mounted) return;
      await widget.onReady();
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() => _error = exception.message.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось сохранить восстановленную личность.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await widget.onReady();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyRecoveryCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Код восстановления скопирован')),
    );
  }
}

class _Introduction extends StatelessWidget {
  const _Introduction({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Brand(),
        SizedBox(height: compact ? 28 : 48),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Личность без анкеты.\nСообщения под вашим ключом.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Text(
            'P2P Messenger создаёт псевдоним и криптографические ключи локально. Для начала не нужны аккаунт, SIM-карта или адрес почты.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 32),
          const Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Feature(icon: Icons.badge_outlined, label: 'Без регистрации'),
              _Feature(icon: Icons.lock_outline, label: 'Ключи на устройстве'),
              _Feature(
                icon: Icons.sync_alt,
                label: 'Relay без открытого текста',
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.hub_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'P2P MESSENGER',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
