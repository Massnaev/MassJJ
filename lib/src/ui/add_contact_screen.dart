import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/identity/anonymous_identity.dart';

enum _ContactEntryMode { camera, code }

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({
    required this.cameraEnabled,
    required this.addContact,
    super.key,
  });

  final bool cameraEnabled;
  final Future<Contact> Function(String code) addContact;

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _codeController = TextEditingController();
  MobileScannerController? _scannerController;
  late _ContactEntryMode _mode;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.cameraEnabled
        ? _ContactEntryMode.camera
        : _ContactEntryMode.code;
    if (widget.cameraEnabled) {
      _scannerController = MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScanner());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    unawaited(_scannerController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить контакт')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Обменяйтесь приглашениями',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Код содержит публичный ключ и право отправлять сообщения. Резервного кода в нём нет.',
                      ),
                      if (widget.cameraEnabled) ...[
                        const SizedBox(height: 16),
                        SegmentedButton<_ContactEntryMode>(
                          segments: const [
                            ButtonSegment(
                              value: _ContactEntryMode.camera,
                              icon: Icon(Icons.qr_code_scanner),
                              label: Text('Камера'),
                            ),
                            ButtonSegment(
                              value: _ContactEntryMode.code,
                              icon: Icon(Icons.keyboard_outlined),
                              label: Text('Ввести код'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (selection) {
                            unawaited(_changeMode(selection.first));
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _mode == _ContactEntryMode.camera
                        ? _cameraView()
                        : _codeView(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraView() {
    final controller = _scannerController!;
    return Padding(
      key: const ValueKey('camera-entry'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: _handleCapture,
                    tapToFocus: true,
                    placeholderBuilder: (_) => const ColoredBox(
                      color: Color(0xFF17201C),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    errorBuilder: (_, error) => _ScannerError(
                      error: error,
                      onUseCode: () =>
                          unawaited(_changeMode(_ContactEntryMode.code)),
                      onRetry: _startScanner,
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 232,
                        height: 232,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _processing
                              ? null
                              : () => controller.toggleTorch(),
                          icon: const Icon(Icons.flashlight_on_outlined),
                          tooltip: 'Включить вспышку',
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: _processing
                              ? null
                              : () => controller.switchCamera(),
                          icon: const Icon(Icons.cameraswitch_outlined),
                          tooltip: 'Сменить камеру',
                        ),
                      ],
                    ),
                  ),
                  if (_processing)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            child: _error == null
                ? const Text(
                    'Наведите камеру на QR-код другого пользователя.',
                    textAlign: TextAlign.center,
                  )
                : Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _codeView() {
    return SingleChildScrollView(
      key: const ValueKey('code-entry'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('contact-code-field'),
            controller: _codeController,
            minLines: 5,
            maxLines: 8,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Код приглашения',
              hintText: 'p2p1.…',
              errorText: _error,
              alignLabelWithHint: true,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _processing ? null : _pasteCode,
            icon: const Icon(Icons.content_paste_outlined),
            label: const Text('Вставить из буфера'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('add-contact-submit'),
            onPressed: _processing ? null : () => _submit(_codeController.text),
            icon: _processing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Добавить контакт'),
          ),
          if (!widget.cameraEnabled) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.desktop_windows_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'На Windows вставьте текстовый код. Камерное сканирование доступно в мобильном приложении.',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startScanner() async {
    final controller = _scannerController;
    if (!mounted || controller == null || _mode != _ContactEntryMode.camera) {
      return;
    }
    try {
      await controller.start();
    } catch (_) {
      // MobileScanner's errorBuilder presents permission and device failures.
    }
  }

  Future<void> _changeMode(_ContactEntryMode mode) async {
    if (_mode == mode || !mounted) return;
    if (mode == _ContactEntryMode.code) {
      await _scannerController?.stop();
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _error = null;
      });
      return;
    }
    setState(() {
      _mode = mode;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanner());
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_processing) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (!value.startsWith('p2p1.')) {
        setState(() => _error = 'Это не QR-приглашение P2P Messenger.');
        continue;
      }
      unawaited(_submit(value));
      return;
    }
  }

  Future<void> _pasteCode() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _error = 'В буфере обмена нет текстового кода.');
      return;
    }
    _codeController.text = text;
    setState(() => _error = null);
  }

  Future<void> _submit(String code) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    if (_mode == _ContactEntryMode.camera) {
      await _scannerController?.stop();
    }
    try {
      final contact = await widget.addContact(code);
      if (!mounted) return;
      Navigator.of(context).pop(contact);
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() => _error = exception.message.toString());
      if (_mode == _ContactEntryMode.camera) await _startScanner();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Не удалось сохранить контакт. Попробуйте ещё раз.',
      );
      if (_mode == _ContactEntryMode.camera) await _startScanner();
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({
    required this.error,
    required this.onUseCode,
    required this.onRetry,
  });

  final MobileScannerException error;
  final VoidCallback onUseCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: const Color(0xFF17201C),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  color: Colors.white,
                  size: 38,
                ),
                const SizedBox(height: 14),
                Text(
                  permissionDenied
                      ? 'Нет доступа к камере'
                      : 'Камера недоступна',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  permissionDenied
                      ? 'Разрешите доступ в настройках устройства или вставьте код вручную.'
                      : 'Попробуйте снова или вставьте текстовый код.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD9E3DD)),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onUseCode,
                  child: const Text('Ввести код'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Попробовать снова'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
