import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/app_controller.dart';
import 'src/core/crypto/mvp_crypto_engine.dart';
import 'src/core/identity/identity_service.dart';
import 'src/core/messaging/message_repository.dart';
import 'src/core/transport/local_outbox_transport.dart';
import 'src/core/transport/transport_router.dart';
import 'src/core/update/update_coordinator.dart';
import 'src/data/local_vault.dart';
import 'src/data/app_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final vault = LocalVault();
  final identityService = IdentityService(vault);
  final messages = MessageRepository(vault);
  final settings = AppSettingsRepository(vault);
  runApp(
    P2PMessengerApp(
      identityService: identityService,
      createController: () async {
        final controller = AppController(
          identityService: identityService,
          messageRepository: messages,
          cryptoEngine: MvpCryptoEngine(),
          transportRouter: TransportRouter([LocalOutboxTransport(messages)]),
          relayUrl: const String.fromEnvironment('RELAY_URL'),
          settingsRepository: settings,
          allowInsecureRelay: const bool.fromEnvironment(
            'ALLOW_INSECURE_RELAY',
          ),
          updateCoordinator: UpdateCoordinator(),
        );
        await controller.initialize();
        return controller;
      },
    ),
  );
}
