import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'core/crypto/crypto_engine.dart';
import 'core/identity/anonymous_identity.dart';
import 'core/identity/identity_service.dart';
import 'core/messaging/chat_message.dart';
import 'core/messaging/message_repository.dart';
import 'core/transport/transport_router.dart';
import 'core/transport/relay_transport.dart';
import 'core/transport/delivery_transport.dart';

class AppController extends ChangeNotifier {
  AppController({
    required IdentityService identityService,
    required MessageRepository messageRepository,
    required CryptoEngine cryptoEngine,
    required TransportRouter transportRouter,
    required String relayUrl,
  }) : _identityService = identityService,
       _messageRepository = messageRepository,
       _cryptoEngine = cryptoEngine,
       _transportRouter = transportRouter,
       _relayUrl = relayUrl;

  final IdentityService _identityService;
  final MessageRepository _messageRepository;
  final CryptoEngine _cryptoEngine;
  final TransportRouter _transportRouter;
  final String _relayUrl;
  final Uuid _uuid = const Uuid();

  late AnonymousIdentity identity;
  List<Contact> contacts = const [];
  List<ChatMessage> messages = const [];
  bool initialized = false;
  RelayTransport? _relayTransport;
  Timer? _pollTimer;
  bool _syncing = false;

  bool get relayConfigured => _relayUrl.isNotEmpty;
  bool get relayReady => _relayTransport?.state == TransportState.ready;

  Future<void> initialize() async {
    identity = await _identityService.loadOrCreate();
    contacts = await _messageRepository.loadContacts();
    messages = await _messageRepository.loadMessages();
    if (_relayUrl.isNotEmpty) {
      final relay = RelayTransport(
        baseUri: Uri.parse(_relayUrl),
        identity: identity,
        findContact: _findContact,
      );
      _relayTransport = relay;
      try {
        await relay.registerMailbox();
        _transportRouter.addTransport(relay);
        await _syncRelay();
      } catch (_) {
        // Offline startup is expected. The local outbox remains available.
      }
      _pollTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => unawaited(_syncRelay()),
      );
    }
    initialized = true;
    notifyListeners();
  }

  Contact? _findContact(String userId) {
    for (final contact in contacts) {
      if (contact.userId == userId) return contact;
    }
    return null;
  }

  Future<void> _syncRelay() async {
    final relay = _relayTransport;
    if (relay == null || _syncing) return;
    _syncing = true;
    try {
      var changed = false;
      if (relay.state != TransportState.ready) {
        await relay.registerMailbox();
        _transportRouter.addTransport(relay);
      }
      final outbox = await _messageRepository.loadOutbox();
      for (final packet in outbox) {
        if (packet.expiresAt.isBefore(DateTime.now().toUtc())) {
          await _messageRepository.removeFromOutbox(packet.messageId);
          continue;
        }
        await relay.send(packet);
        await _messageRepository.removeFromOutbox(packet.messageId);
        ChatMessage? queuedMessage;
        for (final message in messages) {
          if (message.id == packet.messageId) {
            queuedMessage = message;
            break;
          }
        }
        if (queuedMessage != null) {
          _replaceMessage(queuedMessage.copyWith(status: MessageStatus.sent));
          changed = true;
        }
      }
      final packets = await relay.receive();
      for (final packet in packets) {
        try {
          if (!messages.any((message) => message.id == packet.messageId)) {
            final sender = _findContact(packet.senderId);
            if (sender != null) {
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
              changed = true;
            }
          }
        } finally {
          await relay.acknowledge(packet.messageId);
        }
      }
      if (changed) {
        await _messageRepository.saveMessages(messages);
      }
      notifyListeners();
    } catch (_) {
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
