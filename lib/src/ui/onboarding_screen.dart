import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/identity/anonymous_identity.dart';
import 'theme.dart';

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
            if (wide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Row(
                      children: [
                        const Expanded(child: _DesktopIntroduction()),
                        const SizedBox(width: 72),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _panel(_stepContent()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: _step == _OnboardingStep.welcome
                      ? _welcome()
                      : _panel(_stepContent()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _panel(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: child,
        ),
      ),
    );
  }

  Widget _stepContent() => switch (_step) {
    _OnboardingStep.welcome => _welcome(compact: true),
    _OnboardingStep.backup => _backup(),
    _OnboardingStep.restore => _restore(),
  };

  Widget _welcome({bool compact = false}) {
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          const Align(alignment: Alignment.centerLeft, child: _Brand()),
          const SizedBox(height: 38),
        ],
        const _HeroMark(),
        SizedBox(height: compact ? 22 : 28),
        Text(
          'Связь без анкеты\nи центральной точки',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Ключи создаются на устройстве.\nТелефон и почта не нужны.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        const _FeatureCard(
          icon: Icons.verified_user_outlined,
          label: 'Сквозное шифрование',
        ),
        const SizedBox(height: 10),
        const _FeatureCard(
          icon: Icons.wifi_tethering_outlined,
          label: 'LAN, relay и offline outbox',
        ),
        const SizedBox(height: 10),
        const _FeatureCard(
          icon: Icons.person_outline_rounded,
          label: 'Анонимная локальная личность',
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: const ValueKey('create-identity'),
          onPressed: _busy ? null : _createIdentity,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.key_outlined, size: 20),
          label: const Text('Создать личность'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _step = _OnboardingStep.restore;
                  _error = null;
                }),
          icon: const Icon(Icons.settings_backup_restore_rounded, size: 20),
          label: const Text('Восстановить по коду'),
        ),
        if (!compact) ...[
          const SizedBox(height: 20),
          Text(
            'Продолжая, вы создаёте ключи только локально',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.faint),
          ),
        ],
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
        _StepHeader(
          title: 'Сохраните код',
          subtitle: 'Шаг 2 из 3',
          onBack: () => setState(() => _step = _OnboardingStep.welcome),
        ),
        const SizedBox(height: 22),
        const _Notice(
          icon: Icons.key_outlined,
          text:
              'Это единственный способ вернуть личность после потери устройства.',
        ),
        const SizedBox(height: 20),
        Text(
          'RECOVERY CODE',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.muted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.interactive,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            identity.recoveryCode,
            key: const ValueKey('recovery-code'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _copyRecoveryCode(identity.recoveryCode),
          icon: const Icon(Icons.copy_all_outlined, size: 19),
          label: const Text('Копировать код'),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            key: const ValueKey('confirm-backup'),
            value: _savedRecoveryCode,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Я сохранил код в безопасном месте'),
            subtitle: const Text('И никому его не отправлю'),
            onChanged: (value) {
              setState(() => _savedRecoveryCode = value ?? false);
            },
          ),
        ),
        const SizedBox(height: 12),
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
        _StepHeader(
          title: 'Восстановление',
          subtitle: 'Локальная личность',
          onBack: () => setState(() {
            _step = _OnboardingStep.welcome;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),
        const Text(
          'Вставьте резервный код, который начинается с p2pr1. Он будет сохранён в защищённом хранилище этого устройства.',
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('restore-code'),
          controller: _recoveryController,
          minLines: 5,
          maxLines: 8,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Код восстановления',
            hintText: 'p2pr1.…',
            errorText: _error,
            alignLabelWithHint: true,
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

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniMark(),
        SizedBox(width: 10),
        Text(
          'P2P MESSENGER',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
          ),
        ),
      ],
    );
  }
}

class _MiniMark extends StatelessWidget {
  const _MiniMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x397C5CFF),
              blurRadius: 38,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.chat_bubble_outline_rounded, size: 32),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: AppColors.raised,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentSoft),
          const SizedBox(width: 13),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1827),
        border: Border.all(color: AppColors.accentDeep),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: AppColors.accentSoft),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _DesktopIntroduction extends StatelessWidget {
  const _DesktopIntroduction();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Brand(),
        const SizedBox(height: 48),
        Text(
          'Личность без анкеты.\nСообщения под вашим ключом.',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 18),
        Text(
          'Один спокойный интерфейс для прямой связи по LAN, через relay и будущей передачи зашифрованных пакетов без интернета.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}
