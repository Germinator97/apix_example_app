import 'package:apix_example_app/core/services/envelope_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the four envelope-unwrapping methods exposed by apix:
/// `getAndDecodeData`, `getListAndDecodeData`, `getListAndParseData`,
/// `postAndDecodeData`. The custom `dataKey: 'payload'` proves the unwrap
/// honours the configured key.
void main() {
  late EnvelopeDemoClient client;

  setUp(() => client = EnvelopeDemoClient());

  test('getAndDecodeData unwraps {payload: {...}}', () async {
    final user = await client.fetchEnvelopeUser(7);

    expect(user['id'], 7);
    expect(user['name'], 'User 7');
    expect(user.containsKey('email'), isTrue);
  });

  test('getListAndDecodeData unwraps {payload: [...]}', () async {
    final users = await client.fetchEnvelopeUsers();

    expect(users, hasLength(2));
    expect(users.first['name'], 'Alice');
    expect(users.last['name'], 'Bob');
  });

  test('getListAndParseData unwraps a list of primitives', () async {
    final roles = await client.fetchRoles();

    expect(roles, ['admin', 'editor', 'viewer']);
  });

  test('postAndDecodeData echoes the body inside the envelope', () async {
    final created = await client.createEnvelopeUser(name: 'Charlie');

    expect(created['id'], 42);
    expect(created['name'], 'Charlie');
    expect(created.containsKey('created_at'), isTrue);
  });
}
