import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'core/identity/identity_service.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/theme.dart';

typedef ControllerFactory = Future<AppController> Function();

class P2PMessengerApp extends StatefulWidget {
  const P2PMessengerApp({
    required this.identityService,
    required this.createController,
    super.key,
  });

  final IdentityService identityService;
  final ControllerFactory createController;

  @override
  State<P2PMessengerApp> createState() => _P2PMessengerAppState();
}

class _P2PMessengerAppState extends State<P2PMessengerApp>
    with WidgetsBindingObserver {
  AppController? _controller;
  Object? _startupError;
  bool _checkingIdentity = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller?.checkForUpdates());
    }
  }

  Future<void> _bootstrap() async {
    try {
      final exists = await widget.identityService.hasIdentity();
      if (!mounted) return;
      if (!exists) {
        setState(() {
          _checkingIdentity = false;
          _needsOnboarding = true;
        });
        return;
      }
      await _openMessenger();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingIdentity = false;
        _startupError = error;
      });
    }
  }

  Future<void> _openMessenger() async {
    setState(() {
      _checkingIdentity = true;
      _needsOnboarding = false;
      _startupError = null;
    });
    try {
      final controller = await widget.createController();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _checkingIdentity = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingIdentity = false;
        _startupError = error;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MassJJ',
      theme: buildAppTheme(),
      home: _home(),
    );
  }

  Widget _home() {
    final controller = _controller;
    if (controller != null) {
      return HomeShell(controller: controller);
    }
    if (_needsOnboarding) {
      return OnboardingScreen(
        onCreateIdentity: widget.identityService.create,
        onRestoreIdentity: widget.identityService.restore,
        onReady: _openMessenger,
      );
    }
    if (_startupError != null) {
      return _StartupError(
        onRetry: () {
          setState(() {
            _startupError = null;
            _checkingIdentity = true;
          });
          unawaited(_bootstrap());
        },
      );
    }
    return _StartupLoader(active: _checkingIdentity);
  }
}

class _StartupLoader extends StatelessWidget {
  const _StartupLoader({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Открываем локальное хранилище',
          child: active ? const CircularProgressIndicator() : const SizedBox(),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset_outlined, size: 42),
                const SizedBox(height: 18),
                Text(
                  'Не удалось открыть локальное хранилище',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Проверьте доступ к защищённому хранилищу устройства и попробуйте снова.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
