import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/app_controller.dart';
import 'package:p2p_messenger/src/core/crypto/mvp_crypto_engine.dart';
import 'package:p2p_messenger/src/core/identity/identity_service.dart';
import 'package:p2p_messenger/src/core/messaging/chat_message.dart';
import 'package:p2p_messenger/src/core/messaging/message_repository.dart';
import 'package:p2p_messenger/src/core/transport/local_outbox_transport.dart';
import 'package:p2p_messenger/src/core/transport/relay_transport.dart';
import 'package:p2p_messenger/src/core/transport/transport_router.dart';
import 'package:p2p_messenger/src/data/local_vault.dart';

void main() {
  late Directory relayData;
  late Process relayProcess;
  late Uri relayUri;
  final relayErrors = <String>[];

  setUpAll(() async {
    relayData = await Directory.systemTemp.createTemp('p2p-relay-e2e-');
    relayProcess = await Process.start(
      'node',
      ['server/relay.mjs'],
      workingDirectory: Directory.current.path,
      environment: {
        'HOST': '127.0.0.1',
        'PORT': '0',
        'RELAY_STORAGE': '${relayData.path}${Platform.pathSeparator}relay.json',
      },
    );
    relayProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(relayErrors.add);
    final startupLine = await relayProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line.startsWith('Relay listening on '))
        .timeout(const Duration(seconds: 8));
    relayUri = Uri.parse(startupLine.substring('Relay listening on '.length));
  });

  tearDownAll(() async {
    relayProcess.kill();
    try {
      await relayProcess.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      relayProcess.kill(ProcessSignal.sigkill);
    }
    await relayData.delete(recursive: true);
  });

  test(
    'two anonymous clients exchange and acknowledge an encrypted message',
    () async {
      final aliceIdentities = IdentityService(_MemoryVault());
      final bobIdentities = IdentityService(_MemoryVault());
      final alice = await aliceIdentities.create();
      final bob = await bobIdentities.create();
      final bobForAlice = await aliceIdentities.parseInviteCode(
        bobIdentities.createInviteCode(bob),
      );
      final aliceForBob = await bobIdentities.parseInviteCode(
        aliceIdentities.createInviteCode(alice),
      );

      final aliceRelay = RelayTransport(
        baseUri: relayUri,
        identity: alice,
        findContact: (id) => id == bob.userId ? bobForAlice : null,
        allowInsecure: true,
      );
      final bobRelay = RelayTransport(
        baseUri: relayUri,
        identity: bob,
        findContact: (id) => id == alice.userId ? aliceForBob : null,
        allowInsecure: true,
      );
      addTearDown(() {
        aliceRelay.close(force: true);
        bobRelay.close(force: true);
      });

      await aliceRelay.registerMailbox();
      await bobRelay.registerMailbox();
      final clearText = 'Привет, Боб. Это сквозной тест relay.';
      final message = ChatMessage(
        id: 'e2e-message-${DateTime.now().microsecondsSinceEpoch}',
        contactId: bob.userId,
        body: clearText,
        direction: MessageDirection.outgoing,
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.encrypting,
      );
      final crypto = MvpCryptoEngine();
      final packet = await crypto.encrypt(
        message: message,
        sender: alice,
        recipient: bobForAlice,
      );

      final receipt = await aliceRelay.send(packet);
      expect(receipt.messageStatus, MessageStatus.sent);
      expect(packet.cipherText, isNot(utf8.encode(clearText)));

      final received = await bobRelay.receive();
      expect(received, hasLength(1));
      expect(received.single.cryptoSuite, MvpCryptoEngine.suite);
      final decrypted = await crypto.decrypt(
        packet: received.single,
        recipient: bob,
        sender: aliceForBob,
      );
      expect(decrypted, clearText);

      await bobRelay.acknowledge(received.single.messageId);
      expect(await bobRelay.receive(), isEmpty);
      expect(relayErrors, isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  test(
    'app controllers persist, deliver, and receive through the relay',
    () async {
      final aliceVault = _MemoryVault();
      final bobVault = _MemoryVault();
      final aliceIdentities = IdentityService(aliceVault);
      final bobIdentities = IdentityService(bobVault);
      final aliceIdentity = await aliceIdentities.create();
      final bobIdentity = await bobIdentities.create();
      final alice = _buildController(
        vault: aliceVault,
        identities: aliceIdentities,
        relayUrl: relayUri.toString(),
      );
      final bob = _buildController(
        vault: bobVault,
        identities: bobIdentities,
        relayUrl: relayUri.toString(),
      );
      addTearDown(() {
        alice.dispose();
        bob.dispose();
      });

      await alice.initialize();
      await bob.initialize();
      final bobContact = await alice.addContact(
        bobIdentities.createInviteCode(bobIdentity),
      );
      await bob.addContact(aliceIdentities.createInviteCode(aliceIdentity));

      const clearText = 'Сообщение через полный AppController';
      await alice.sendMessage(bobContact, clearText);
      expect(alice.messages.single.status, MessageStatus.sent);

      await bob.synchronize();
      expect(bob.messages, hasLength(1));
      expect(bob.messages.single.body, clearText);
      expect(bob.messages.single.direction, MessageDirection.incoming);
      expect(bob.messages.single.status, MessageStatus.delivered);

      final storedMessages = await MessageRepository(bobVault).loadMessages();
      expect(storedMessages.single.body, clearText);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}

AppController _buildController({
  required JsonVault vault,
  required IdentityService identities,
  required String relayUrl,
}) {
  final messages = MessageRepository(vault);
  return AppController(
    identityService: identities,
    messageRepository: messages,
    cryptoEngine: MvpCryptoEngine(),
    transportRouter: TransportRouter([LocalOutboxTransport(messages)]),
    relayUrl: relayUrl,
    allowInsecureRelay: true,
    enableNearby: false,
  );
}

class _MemoryVault implements JsonVault {
  final Map<String, Map<String, Object?>> _values = {};

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final value = _values[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> writeJson(String key, Map<String, Object?> value) async {
    _values[key] = Map<String, Object?>.from(value);
  }
}
