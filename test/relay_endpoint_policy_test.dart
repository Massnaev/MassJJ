import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/transport/relay_endpoint_policy.dart';

void main() {
  test('accepts an HTTPS relay origin', () {
    expect(
      RelayEndpointPolicy.parse('https://relay.example.org/').toString(),
      'https://relay.example.org',
    );
  });

  test('rejects cleartext and credential-bearing relay URLs', () {
    expect(
      () => RelayEndpointPolicy.parse('http://relay.example.org'),
      throwsFormatException,
    );
    expect(
      () => RelayEndpointPolicy.parse('https://token@relay.example.org'),
      throwsFormatException,
    );
  });

  test('allows explicit insecure development relay', () {
    expect(
      RelayEndpointPolicy.parse(
        'http://127.0.0.1:8787',
        allowInsecure: true,
      ).port,
      8787,
    );
  });
}
