import 'package:apix/apix.dart';

import 'demo_probe.dart';
import 'scripted_adapter.dart';

/// What the cache does, and what it must never do.
///
/// Two of these show a wrong *answer* rather than a failure: the cache handed
/// back a body that belonged to someone else, or to another page. Nothing
/// raised, which is why both survived every review until an audit went looking.
List<DemoProbe> cacheProbes() => [
  DemoProbe(
    id: 'cache.scoped_to_caller',
    theme: ProbeTheme.cache,
    label: 'Scoped to the caller',
    run: _scopedToCaller,
  ),
  DemoProbe(
    id: 'cache.inline_query',
    theme: ProbeTheme.cache,
    label: 'Inline ?page= does not collide',
    run: _inlineQuery,
  ),
  DemoProbe(
    id: 'cache.network_only_writes_nothing',
    theme: ProbeTheme.cache,
    label: 'networkOnly writes nothing',
    run: _networkOnlyWritesNothing,
  ),
  DemoProbe(
    id: 'cache.dedup_without_cache',
    theme: ProbeTheme.cache,
    label: 'Dedup without a cache',
    run: _dedupWithoutCache,
  ),
];

/// Log out, log back in as someone else, ask for `/me` again.
Future<ProbeOutcome> _scopedToCaller() async {
  // Echoes the token back, so the body itself says which account it belongs to.
  final adapter = ScriptedAdapter(
    (options) => {'me': options.headers['Authorization']},
  );
  final tokens = MutableTokenProvider('token-A');
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    authConfig: AuthConfig(tokenProvider: tokens),
    cacheConfig: CacheConfig(
      strategy: CacheStrategy.cacheFirst,
      defaultTtl: const Duration(minutes: 10),
    ),
    httpClientAdapter: adapter,
  );

  final asA = await client.get<dynamic>('/me');
  tokens.accessToken = 'token-B';
  final asB = await client.get<dynamic>('/me');

  final bodyA = (asA.data as Map)['me'];
  final bodyB = (asB.data as Map)['me'];

  return ProbeOutcome(
    headline: bodyA == bodyB
        ? 'LEAK — B was served "$bodyA"'
        : 'A got "$bodyA", B got "$bodyB" (${adapter.hits} calls)',
    detail:
        'The key described what was asked and never who asked, so two accounts '
        'on one device shared every entry — and FileCacheStorage persists, so '
        'the leak outlived the session. Scoped now by CacheConfig.varyHeaders, '
        'on a digest, so no bearer token is written beside the entry.',
  );
}

/// The same endpoint, two pages, written the way most callers write them.
Future<ProbeOutcome> _inlineQuery() async {
  final adapter = ScriptedAdapter((options) => {'uri': options.uri.toString()});
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    cacheConfig: CacheConfig(
      strategy: CacheStrategy.cacheFirst,
      defaultTtl: const Duration(minutes: 10),
    ),
    httpClientAdapter: adapter,
  );

  final first = await client.get<dynamic>('/users?page=1');
  final second = await client.get<dynamic>('/users?page=2');

  final firstUri = (first.data as Map)['uri'] as String;
  final secondUri = (second.data as Map)['uri'] as String;

  return ProbeOutcome(
    headline: firstUri == secondUri
        ? 'COLLISION — page=2 was served page=1'
        : '2 pages → ${adapter.hits} calls, distinct bodies',
    detail:
        'The key was rebuilt from queryParameters, which is empty when the '
        'caller writes the query into the path — so both pages shared one '
        'entry. The same two pages passed as queryParameters did not collide, '
        'so whether it fired depended on how you spelled the call.',
  );
}

/// `networkOnly` documents "never read cache" — it also never writes.
Future<ProbeOutcome> _networkOnlyWritesNothing() async {
  final storage = InMemoryCacheStorage();
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    cacheConfig: CacheConfig(
      storage: storage,
      strategy: CacheStrategy.networkOnly,
    ),
    httpClientAdapter: ScriptedAdapter(
      (options) => {'email': 'jane@example.test', 'plan': 'premium'},
    ),
  );

  await client.get<dynamic>('/quota');
  final stored = await storage.keys();

  return ProbeOutcome(
    headline: stored.isEmpty
        ? 'Nothing written to the store'
        : 'LEAK — ${stored.length} entr${stored.length == 1 ? "y" : "ies"} '
              'written',
    detail:
        'Until 4.0.0 only the *reading* half was enforced, so a profile went '
        'through a store nobody ever read from.',
  );
}

/// Deduplication with no `cacheConfig` anywhere in sight.
Future<ProbeOutcome> _dedupWithoutCache() async {
  final adapter = ScriptedAdapter((options) => {'value': 'ok'});
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    deduplicationConfig: const DeduplicationConfig(),
    httpClientAdapter: adapter,
  );

  await Future.wait([
    client.get<dynamic>('/profile'),
    client.get<dynamic>('/profile'),
    client.get<dynamic>('/profile'),
  ]);
  final concurrent = adapter.hits;

  // A later request must still reach the network: this is deduplication, not
  // caching.
  await client.get<dynamic>('/profile');

  return ProbeOutcome(
    headline:
        '3 concurrent GETs → $concurrent call, '
        '${adapter.hits - concurrent} more when repeated later',
    detail:
        'No cacheConfig at all. Before 4.0.0 this required installing the '
        'cache, then supplying a CacheStorage that dropped its writes.',
  );
}
