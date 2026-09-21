import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/app_controller.dart';
import 'package:p2p_messenger/src/core/crypto/mvp_crypto_engine.dart';
import 'package:p2p_messenger/src/core/identity/anonymous_identity.dart';
import 'package:p2p_messenger/src/core/identity/identity_service.dart';
import 'package:p2p_messenger/src/core/messaging/chat_message.dart';
import 'package:p2p_messenger/src/core/messaging/message_repository.dart';
import 'package:p2p_messenger/src/core/transport/transport_router.dart';
import 'package:p2p_messenger/src/data/local_vault.dart';
import 'package:p2p_messenger/src/ui/add_contact_screen.dart';
import 'package:p2p_messenger/src/ui/chat_screen.dart';
import 'package:p2p_messenger/src/ui/home_shell.dart';
import 'package:p2p_messenger/src/ui/invite_code_panel.dart';
import 'package:p2p_messenger/src/ui/onboarding_screen.dart';
import 'package:p2p_messenger/src/ui/theme.dart';

void main() {
  const phoneSize = Size(390, 844);
  const identity = AnonymousIdentity(
    userId: 'local-test-user',
    displayName: 'Nikita',
    publicKey: <int>[1, 2, 3, 4],
    privateSeed: <int>[5, 6, 7, 8],
    fingerprint: '71A2 93C0 4B19 8E11',
    inboxReadToken: 'test-read-token',
    inboxWriteToken: 'test-write-token',
  );

  setUpAll(_loadPreviewFont);

  Future<void> setPhone(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('approved onboarding welcome', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: OnboardingScreen(
          onCreateIdentity: () async => identity,
          onRestoreIdentity: (_) async => identity,
          onReady: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/android_onboarding_welcome.png'),
    );
  });

  testWidgets('approved onboarding backup', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: OnboardingScreen(
          onCreateIdentity: () async => identity,
          onRestoreIdentity: (_) async => identity,
          onReady: () async {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('create-identity')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('goldens/android_onboarding_backup.png'),
    );
  });

  testWidgets('approved populated chats', (tester) async {
    await setPhone(tester);
    final controller = _previewController(identity);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: HomeShell(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeShell),
      matchesGoldenFile('goldens/android_chats.png'),
    );
  });

  testWidgets('approved contacts list', (tester) async {
    await setPhone(tester);
    final controller = _previewController(identity);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: HomeShell(controller: controller),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Контакты'),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeShell),
      matchesGoldenFile('goldens/android_contacts.png'),
    );
  });

  testWidgets('approved conversation', (tester) async {
    await setPhone(tester);
    final controller = _previewController(identity);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: HomeShell(controller: controller),
      ),
    );
    await tester.tap(find.text('Маша К.'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ChatScreen),
      matchesGoldenFile('goldens/android_conversation.png'),
    );
  });

  testWidgets('approved profile', (tester) async {
    await setPhone(tester);
    final controller = _previewController(identity);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: HomeShell(controller: controller),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Профиль'),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HomeShell),
      matchesGoldenFile('goldens/android_profile.png'),
    );
  });

  testWidgets('approved manual contact entry', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AddContactScreen(
          cameraEnabled: false,
          addContact: (_) async => throw const FormatException('Ошибка'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AddContactScreen),
      matchesGoldenFile('goldens/android_add_contact.png'),
    );
  });

  testWidgets('approved invitation panel', (tester) async {
    await setPhone(tester);
    final invite = IdentityService(_MemoryVault()).createInviteCode(identity);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: InviteCodePanel(inviteCode: invite, onCopy: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(InviteCodePanel),
      matchesGoldenFile('goldens/android_invite.png'),
    );
  });
}

Future<void> _loadPreviewFont() async {
  final roots = <Directory>[];
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null) roots.add(Directory(configuredRoot));
  if (Platform.isWindows) roots.add(Directory(r'C:\tools\flutter'));
  var executableParent = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    roots.add(executableParent);
    final parent = executableParent.parent;
    if (parent.path == executableParent.path) break;
    executableParent = parent;
  }
  File? fontFile;
  for (final root in roots) {
    final candidate = File(
      '${root.path}${Platform.pathSeparator}engine${Platform.pathSeparator}'
      'src${Platform.pathSeparator}flutter${Platform.pathSeparator}txt'
      '${Platform.pathSeparator}third_party${Platform.pathSeparator}fonts'
      '${Platform.pathSeparator}Roboto-Regular.ttf',
    );
    if (candidate.existsSync()) {
      fontFile = candidate;
      break;
    }
  }
  if (fontFile == null) return;
  final bytes = await fontFile.readAsBytes();
  final loader = FontLoader('Segoe UI Variable')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
  final monospaceLoader = FontLoader('monospace')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await monospaceLoader.load();

  for (final root in roots) {
    final candidate = File(
      '${root.path}${Platform.pathSeparator}bin${Platform.pathSeparator}cache'
      '${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}resources${Platform.pathSeparator}devtools'
      '${Platform.pathSeparator}assets${Platform.pathSeparator}fonts'
      '${Platform.pathSeparator}MaterialIcons-Regular.otf',
    );
    if (!candidate.existsSync()) continue;
    final iconBytes = await candidate.readAsBytes();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await iconLoader.load();
    break;
  }
}

AppController _previewController(AnonymousIdentity identity) {
  final vault = _MemoryVault();
  final controller = AppController(
    identityService: IdentityService(vault),
    messageRepository: MessageRepository(vault),
    cryptoEngine: MvpCryptoEngine(),
    transportRouter: TransportRouter(const []),
    relayUrl: '',
    enableNearby: false,
  );
  controller.identity = identity;
  controller.contacts = const [
    Contact(
      userId: 'masha',
      displayName: 'Маша К.',
      publicKey: [10, 11, 12],
      fingerprint: '4C12 90EE 7A20 31D8',
      inboxWriteToken: 'masha-write',
    ),
    Contact(
      userId: 'anton',
      displayName: 'Антон К.',
      publicKey: [20, 21, 22],
      fingerprint: 'A184 2F03 19D1 80C7',
      inboxWriteToken: 'anton-write',
    ),
    Contact(
      userId: 'lena',
      displayName: 'Лена',
      publicKey: [30, 31, 32],
      fingerprint: '0E21 BB49 30A2 910F',
      inboxWriteToken: 'lena-write',
    ),
  ];
  controller.messages = [
    ChatMessage(
      id: '1',
      contactId: 'masha',
      body: 'Отправила фото · только что',
      direction: MessageDirection.incoming,
      createdAt: DateTime(2026, 9, 21, 14, 32),
      status: MessageStatus.delivered,
    ),
    ChatMessage(
      id: '2',
      contactId: 'anton',
      body: 'Увидимся вечером?',
      direction: MessageDirection.incoming,
      createdAt: DateTime(2026, 9, 21, 14, 2),
      status: MessageStatus.delivered,
    ),
    ChatMessage(
      id: '4',
      contactId: 'masha',
      body: 'Да, вижу тебя по LAN',
      direction: MessageDirection.outgoing,
      createdAt: DateTime(2026, 9, 21, 14, 33),
      status: MessageStatus.delivered,
    ),
    ChatMessage(
      id: '3',
      contactId: 'lena',
      body: 'Сообщение ждёт сети',
      direction: MessageDirection.outgoing,
      createdAt: DateTime(2026, 9, 21, 13, 11),
      status: MessageStatus.queued,
    ),
  ];
  return controller;
}

class _MemoryVault implements JsonVault {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => _data[key];

  @override
  Future<void> writeJson(String key, Map<String, Object?> value) async {
    _data[key] = Map<String, dynamic>.from(value);
  }
}
