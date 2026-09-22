import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'core/crypto/crypto_engine.dart';
import 'core/identity/anonymous_identity.dart';
import 'core/identity/identity_service.dart';
import 'core/messaging/chat_message.dart';
import 'core/messaging/encrypted_packet.dart';
import 'core/messaging/message_repository.dart';
import 'core/transport/delivery_transport.dart';
import 'core/transport/nearby_runtime.dart';
import 'core/transport/relay_endpoint_policy.dart';
import 'core/transport/relay_transport.dart';
import 'core/transport/transport_router.dart';
import 'core/update/update_coordinator.dart';
import 'data/app_settings_repository.dart';

class AppController extends ChangeNotifier {
  AppController({
    required IdentityService identityService,
    required MessageRepository messageRepository,
    required CryptoEngine cryptoEngine,
    required TransportRouter transportRouter,
    required String relayUrl,
    AppSettingsRepository? settingsRepository,
    bool allowInsecureRelay = false,
    UpdateCoordinator? updateCoordinator,
    bool enableNearby = true,
  }) : _identityService = identityService,
       _messageRepository = messageRepository,
       _cryptoEngine = cryptoEngine,
       _transportRouter = transportRouter,
       _relayUrl = relayUrl.trim(),
       _settingsRepository = settingsRepository,
       _allowInsecureRelay = allowInsecureRelay,
       _enableNearby = enableNearby {
    updates = updateCoordinator ?? UpdateCoordinator.disabled();
    updates.addListener(_onUpdateChanged);
  }

  final IdentityService _identityService;
  final MessageRepository _messageRepository;
  final CryptoEngine _cryptoEngine;
  final TransportRouter _transportRouter;
  String _relayUrl;
  final AppSettingsRepository? _settingsRepository;
  final bool _allowInsecureRelay;
  final bool _enableNearby;
  late final UpdateCoordinator updates;
  final Uuid _uuid = const Uuid();

  late AnonymousIdentity identity;
  List<Contact> contacts = const [];
  List<ChatMessage> messages = const [];
  bool initialized = false;
  RelayTransport? _relayTransport;
  NearbyRuntime? _nearbyRuntime;
  Timer? _pollTimer;
  Timer? _updateTimer;
  bool _syncing = false;
  bool _disposed = false;
  String? nearbyError;
  String? relayError;
  final Set<String> _processingIncoming = {};

  bool get relayConfigured => _relayUrl.isNotEmpty;
  bool get relayReady => _relayTransport?.state == TransportState.ready;
  String get relayUrl => _relayUrl;
  bool get nearbyReady => _nearbyRuntime != null;
  int get nearbyPeerCount => _nearbyRuntime?.peerCount ?? 0;
  CryptoEngineInfo get cryptoInfo => _cryptoEngine.info;

  bool isContactNearby(String contactId) {
    return _nearbyRuntime?.isNearby(contactId) ?? false;
  }

  Future<void> initialize() async {
    identity = await _identityService.load();
    contacts = await _messageRepository.loadContacts();
    messages = await _messageRepository.loadMessages();
    final storedRelayUrl = await _settingsRepository?.loadRelayUrl();
    if (storedRelayUrl != null) _relayUrl = storedRelayUrl.trim();
    if (_enableNearby) {
      final runtime = NearbyRuntime(
        identity: identity,
        contacts: () => contacts,
        onPacket: _acceptIncoming,
        onPeersChanged: _onNearbyPeersChanged,
      );
      _nearbyRuntime = runtime;
      try {
        await runtime.start();
        _transportRouter.addTransport(runtime.transport);
      } catch (error) {
        nearbyError = error.toString();
        _nearbyRuntime = null;
      }
    }
    await _startRelay();
    await _syncTransports();
    _ensurePollTimer();
    initialized = true;
    notifyListeners();
    unawaited(updates.check());
    _updateTimer = Timer.periodic(
      const Duration(hours: 3),
      (_) => unawaited(updates.check(force: true)),
    );
  }

  Contact? _findContact(String userId) {
    for (final contact in contacts) {
      if (contact.userId == userId) return contact;
    }
    return null;
  }

  Future<void> _startRelay() async {
    if (_relayUrl.isEmpty) return;
    try {
      final baseUri = RelayEndpointPolicy.parse(
        _relayUrl,
        allowInsecure: _allowInsecureRelay,
      );
      final relay = RelayTransport(
        baseUri: baseUri,
        identity: identity,
        findContact: _findContact,
        allowInsecure: _allowInsecureRelay,
      );
      _relayTransport = relay;
      await relay.registerMailbox();
      _transportRouter.addTransport(relay);
      relayError = null;
    } on FormatException catch (error) {
      relayError = error.message;
      _relayTransport = null;
    } catch (_) {
      relayError = 'Relay настроен, но сейчас недоступен.';
      // Keep the transport instance so the periodic synchronizer can retry.
    }
  }

  Future<void> configureRelay(String rawUrl) async {
    final next = rawUrl.trim();
    if (next.isNotEmpty) {
      RelayEndpointPolicy.parse(next, allowInsecure: _allowInsecureRelay);
    }
    final previous = _relayTransport;
    _relayTransport = null;
    _transportRouter.removeTransport(TransportKind.internetRelay);
    previous?.close(force: true);
    _relayUrl = next;
    relayError = null;
    await _settingsRepository?.saveRelayUrl(next);
    await _startRelay();
    _ensurePollTimer();
    await _syncTransports();
    notifyListeners();
  }

  void _ensurePollTimer() {
    if (_pollTimer != null ||
        (_nearbyRuntime == null && _relayTransport == null)) {
      return;
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_syncTransports()),
    );
  }

  void _onNearbyPeersChanged() {
    if (_disposed) return;
    notifyListeners();
    unawaited(_syncTransports());
  }

  void _onUpdateChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> synchronize() => _syncTransports();

  Future<void> checkForUpdates() => updates.check();

  Future<void> _syncTransports() async {
    final relay = _relayTransport;
    if (_syncing) return;
    _syncing = true;
    try {
      if (relay != null && relay.state != TransportState.ready) {
        try {
          await relay.registerMailbox();
          _transportRouter.addTransport(relay);
          relayError = null;
        } catch (_) {
          relayError = 'Relay настроен, но сейчас недоступен.';
          // Nearby and the local outbox remain available without the relay.
        }
      }
      await _retryOutbox();
      if (relay == null || relay.state != TransportState.ready) return;
      final packets = await relay.receive();
      for (final packet in packets) {
        try {
          await _acceptIncoming(packet);
        } finally {
          await relay.acknowledge(packet.messageId);
        }
      }
      notifyListeners();
    } catch (_) {
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _retryOutbox() async {
    var changed = false;
    try {
      final outbox = await _messageRepository.loadOutbox();
      for (final packet in outbox) {
        if (packet.expiresAt.isBefore(DateTime.now().toUtc())) {
          await _messageRepository.removeFromOutbox(packet.messageId);
          continue;
        }
        final receipt = await _transportRouter.send(packet);
        if (receipt.transport == TransportKind.localOutbox) continue;
        await _messageRepository.removeFromOutbox(packet.messageId);
        ChatMessage? queuedMessage;
        for (final message in messages) {
          if (message.id == packet.messageId) {
            queuedMessage = message;
            break;
          }
        }
        if (queuedMessage != null) {
          _replaceMessage(
            queuedMessage.copyWith(status: receipt.messageStatus),
          );
          changed = true;
        }
      }
      if (changed) {
        await _messageRepository.saveMessages(messages);
      }
    } catch (_) {
      // The packet stays in the encrypted outbox for the next route attempt.
    }
  }

  Future<bool> _acceptIncoming(EncryptedPacket packet) async {
    if (messages.any((message) => message.id == packet.messageId)) return true;
    if (!_processingIncoming.add(packet.messageId)) return true;
    try {
      final sender = _findContact(packet.senderId);
      if (sender == null) return false;
      final body = await _cryptoEngine.decrypt(
        packet: packet,
        recipient: identity,
        sender: sender,
      );
      messages = [
        ...messages,
        ChatMessage(
          id: packet.messageId,
          contactId: sender.userId,
          body: body,
          direction: MessageDirection.incoming,
          createdAt: packet.createdAt,
          status: MessageStatus.delivered,
        ),
      ];
      await _messageRepository.saveMessages(messages);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      _processingIncoming.remove(packet.messageId);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _updateTimer?.cancel();
    updates.removeListener(_onUpdateChanged);
    updates.dispose();
    unawaited(_nearbyRuntime?.close());
    _relayTransport?.close(force: true);
    super.dispose();
  }

  String get inviteCode => _identityService.createInviteCode(identity);

  List<ChatMessage> messagesFor(String contactId) {
    return messages.where((message) => message.contactId == contactId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  ChatMessage? lastMessageFor(String contactId) {
    final matching = messagesFor(contactId);
    return matching.isEmpty ? null : matching.last;
  }

  Future<Contact> addContact(String code) async {
    final contact = await _identityService.parseInviteCode(code);
    if (contact.userId == identity.userId) {
      throw const FormatException('Нельзя добавить собственный код.');
    }
    if (contacts.any((item) => item.userId == contact.userId)) {
      throw const FormatException('Этот контакт уже добавлен.');
    }

    contacts = [...contacts, contact];
    await _messageRepository.saveContacts(contacts);
    await _nearbyRuntime?.refreshContacts();
    notifyListeners();
    return contact;
  }

  Future<void> sendMessage(Contact contact, String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;

    final now = DateTime.now().toUtc();
    final message = ChatMessage(
      id: _uuid.v7(),
      contactId: contact.userId,
      body: text,
      direction: MessageDirection.outgoing,
      createdAt: now,
      status: MessageStatus.encrypting,
    );
    messages = [...messages, message];
    notifyListeners();

    try {
      final packet = await _cryptoEngine.encrypt(
        message: message,
        sender: identity,
        recipient: contact,
      );
      final receipt = await _transportRouter.send(packet);
      _replaceMessage(message.copyWith(status: receipt.messageStatus));
    } catch (_) {
      _replaceMessage(message.copyWith(status: MessageStatus.failed));
      rethrow;
    }

    await _messageRepository.saveMessages(messages);
    notifyListeners();
  }

  void _replaceMessage(ChatMessage replacement) {
    messages = [
      for (final message in messages)
        if (message.id == replacement.id) replacement else message,
    ];
  }
}
