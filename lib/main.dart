import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/app_controller.dart';
import 'src/core/crypto/mvp_crypto_engine.dart';
import 'src/core/identity/identity_service.dart';
import 'src/core/messaging/message_repository.dart';
import 'src/core/transport/local_outbox_transport.dart';
import 'src/core/transport/transport_router.dart';
import 'src/data/local_vault.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final vault = LocalVault();
  final messages = MessageRepository(vault);
  final controller = AppController(
    identityService: IdentityService(vault),
    messageRepository: messages,
    cryptoEngine: MvpCryptoEngine(),
    transportRouter: TransportRouter([LocalOutboxTransport(messages)]),
    relayUrl: const String.fromEnvironment('RELAY_URL'),
  );

  await controller.initialize();
  runApp(P2PMessengerApp(controller: controller));
}
