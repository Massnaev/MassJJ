import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/crypto/mvp_crypto_engine.dart';
import 'package:p2p_messenger/src/core/identity/anonymous_identity.dart';
import 'package:p2p_messenger/src/core/identity/identity_service.dart';
import 'package:p2p_messenger/src/core/messaging/chat_message.dart';
import 'package:p2p_messenger/src/core/messaging/encrypted_packet.dart';
import 'package:p2p_messenger/src/core/transport/delivery_transport.dart';
import 'package:p2p_messenger/src/core/transport/nearby_discovery_tagger.dart';
import 'package:p2p_messenger/src/core/transport/nearby_inbox_server.dart';
import 'package:p2p_messenger/src/core/transport/nearby_peer_registry.dart';
import 'package:p2p_messenger/src/core/transport/nearby_transport.dart';
import 'package:p2p_messenger/src/data/local_vault.dart';

void main() {
  test('directed discovery tags match only the expected advertiser', () async {
    final pair = await _identityPair();
    final tagger = NearbyDiscoveryTagger();
    final now = DateTime.utc(2026, 9, 13, 12, 0, 10);

    final aliceTag = await tagger.tagFor(
      identity: pair.alice,
      contact: pair.bobForAlice,
      at: now,
    );
    final bobTag = await tagger.tagFor(
      identity: pair.bob,
      contact: pair.aliceForBob,
      at: now,
    );
    final laterTag = await tagger.tagFor(
      identity: pair.alice,
      contact: pair.bobForAlice,
      at: now.add(const Duration(minutes: 2)),
    );

    expect(aliceTag, isNot(bobTag));
    expect(aliceTag, isNot(laterTag));
    expect(aliceTag, isNot(contains(pair.alice.userId)));
    final accepted = await tagger.acceptedTags(
      identity: pair.bob,
      contacts: [pair.aliceForBob],
      at: now.add(const Duration(minutes: 1)),
    );
    expect(accepted[aliceTag], pair.alice.userId);
    expect(accepted[bobTag], isNull);
  });

  test('nearby transport delivers an encrypted packet directly', () async {
    final pair = await _identityPair();
    EncryptedPacket? received;
    final server = NearbyInboxServer(
      identity: pair.bob,
      onPacket: (packet) async {
        received = packet;
        return true;
      },
    );
    await server.start();
    final registry = NearbyPeerRegistry()
      ..update(
        contactId: pair.bob.userId,
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
        serviceName: 'test-bob',
      );
    final transport = NearbyTransport(registry: registry);
    addTearDown(() async {
      transport.close(force: true);
      await server.close();
    });
    final crypto = MvpCryptoEngine();
    const clearText = 'Прямое сообщение в локальной сети';
    final packet = await crypto.encrypt(
      message: ChatMessage(
        id: 'nearby-message-0001',
        contactId: pair.bob.userId,
        body: clearText,
        direction: MessageDirection.outgoing,
        createdAt: DateTime.now().toUtc(),
        status: MessageStatus.encrypting,
      ),
      sender: pair.alice,
      recipient: pair.bobForAlice,
    );

    final receipt = await transport.send(packet);

    expect(receipt.transport, TransportKind.nearby);
    expect(receipt.messageStatus, MessageStatus.delivered);
    expect(received, isNotNull);
    expect(
      utf8.decode(received!.cipherText, allowMalformed: true),
      isNot(clearText),
    );
    expect(
      await crypto.decrypt(
        packet: received!,
        recipient: pair.bob,
        sender: pair.aliceForBob,
      ),
      clearText,
    );
  });
}

Future<
  ({
    AnonymousIdentity alice,
    AnonymousIdentity bob,
    Contact bobForAlice,
    Contact aliceForBob,
  })
>
_identityPair() async {
  final aliceIdentities = IdentityService(_MemoryVault());
  final bobIdentities = IdentityService(_MemoryVault());
  final alice = await aliceIdentities.create();
  final bob = await bobIdentities.create();
  return (
    alice: alice,
    bob: bob,
    bobForAlice: await aliceIdentities.parseInviteCode(
      bobIdentities.createInviteCode(bob),
    ),
    aliceForBob: await bobIdentities.parseInviteCode(
      aliceIdentities.createInviteCode(alice),
    ),
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
