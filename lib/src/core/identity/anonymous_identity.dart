import 'dart:convert';

class AnonymousIdentity {
  const AnonymousIdentity({
    required this.userId,
    required this.displayName,
    required this.publicKey,
    required this.privateSeed,
    required this.fingerprint,
    required this.inboxReadToken,
    required this.inboxWriteToken,
  });

  final String userId;
  final String displayName;
  final List<int> publicKey;
  final List<int> privateSeed;
  final String fingerprint;
  final String inboxReadToken;
  final String inboxWriteToken;

  String get recoveryCode {
    final bundle = jsonEncode({
      'v': 1,
      'seed': base64UrlEncode(privateSeed),
      'read': inboxReadToken,
      'write': inboxWriteToken,
    });
    return 'p2pr1.${base64UrlEncode(utf8.encode(bundle)).replaceAll('=', '')}';
  }
}

class Contact {
  const Contact({
    required this.userId,
    required this.displayName,
    required this.publicKey,
    required this.fingerprint,
    required this.inboxWriteToken,
  });

  final String userId;
  final String displayName;
  final List<int> publicKey;
  final String fingerprint;
  final String inboxWriteToken;

  Map<String, Object?> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'publicKey': base64UrlEncode(publicKey),
        'fingerprint': fingerprint,
        'inboxWriteToken': inboxWriteToken,
      };

  factory Contact.fromJson(Map<String, Object?> json) {
    return Contact(
      userId: json['userId']! as String,
      displayName: json['displayName']! as String,
      publicKey: base64Url.decode(json['publicKey']! as String),
      fingerprint: json['fingerprint']! as String,
      inboxWriteToken: json['inboxWriteToken']! as String,
    );
  }
}
