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
  DemoProbe(
    id: 'cache.body_in_key',
    theme: ProbeTheme.cache,
    label: 'Two POSTs, two answers',
    run: _bodyInKey,
  ),
  DemoProbe(
    id: 'cache.write_failure_sends_once',
    theme: ProbeTheme.cache,
    label: 'A broken store sends one request',
    run: _writeFailureSendsOnce,
  ),
  DemoProbe(
    id: 'cache.listing_is_not_deleting',
    theme: ProbeTheme.cache,
    label: 'Listing keys keeps the fallback',
    run: _listingIsNotDeleting,
  ),
  DemoProbe(
    id: 'cache.hits_are_reportable',
    theme: ProbeTheme.cache,
    label: 'A hit no observer could see',
    run: _hitsAreReportable,
  ),
];

/// A [CacheStorage] whose writes always fail, like a full disk would.
class _RefusingStorage extends InMemoryCacheStorage {
  @override
  Future<void> set(String key, CacheEntry entry) async {
    throw StateError('disk unavailable');
  }
}

/// Cache a POST, then send the same endpoint a different payload.
Future<ProbeOutcome> _bodyInKey() async {
  var answers = 0;
  final adapter = ScriptedAdapter((options) => {'n': ++answers});
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    cacheConfig: CacheConfig(
      strategy: CacheStrategy.cacheFirst,
      defaultTtl: const Duration(minutes: 10),
      cacheableMethods: const ['GET', 'POST'],
      enableDeduplication: false,
    ),
    httpClientAdapter: adapter,
  );

  final alice = await client.post<dynamic>('/search', data: {'q': 'alice'});
  final bob = await client.post<dynamic>('/search', data: {'q': 'bob'});

  final a = (alice.data as Map)['n'];
  final b = (bob.data as Map)['n'];

  return ProbeOutcome(
    headline: a == b
        ? 'COLLISION — bob was served answer $a'
        : 'alice got $a, bob got $b (${adapter.hits} calls)',
    detail:
        'cacheableMethods is a public list and nothing stopped anyone adding '
        'POST, but the key described method + url + caller and never the '
        'payload — so two searches shared one entry. The deduplicator had '
        'hashed the body from the start, which is what made it invisible: half '
        'the package was right. One shared bodyFingerprint now feeds both keys.',
  );
}

/// Break the store, then send one request.
Future<ProbeOutcome> _writeFailureSendsOnce() async {
  var answers = 0;
  final adapter = ScriptedAdapter((options) => {'n': ++answers});
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    cacheConfig: CacheConfig(
      storage: _RefusingStorage(),
      strategy: CacheStrategy.networkFirst,
    ),
    httpClientAdapter: adapter,
  );

  final response = await client.get<dynamic>('/orders');
  final served = (response.data as Map)['n'];

  return ProbeOutcome(
    headline: '${adapter.hits} network call, body n=$served',
    detail:
        'The write ran before the resolve, so a storage failure escaped to the '
        'interceptor\'s catch — which falls through to the network and sent '
        'the request again. Two calls, and the caller was handed the SECOND '
        'answer: not wasted traffic but a different result than the one '
        'actually computed first. Nothing raised; the store is yours, so it '
        'fails for reasons apix cannot see.',
  );
}

/// Expire an entry, list the keys, then lose the network.
Future<ProbeOutcome> _listingIsNotDeleting() async {
  var offline = false;
  final adapter = ScriptedAdapter((options) {
    if (offline) throw const Unauthorized();
    return {'quota': 4200};
  });
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    cacheConfig: CacheConfig(
      strategy: CacheStrategy.networkFirst,
      defaultTtl: const Duration(milliseconds: 20),
    ),
    httpClientAdapter: adapter,
  );

  await client.get<dynamic>('/quota');
  await Future<void>.delayed(const Duration(milliseconds: 40));

  // A read-only operation, between the entry expiring and the network dying.
  final keys = await client.cacheInterceptor!.getCacheKeys();

  offline = true;
  final served = await client.get<dynamic>('/quota');

  return ProbeOutcome(
    headline:
        'listed ${keys.length} key, offline fallback served '
        '${(served.data as Map)['quota']} (stale: ${served.isStale})',
    detail:
        'keys() purged every expired entry as it walked, so asking what was '
        'cached destroyed the offline fallback — and an expired entry IS what '
        'networkFirst serves when the network is gone. A missing entry looks '
        'exactly like one that was never written. The sweep still exists, '
        'under evictExpired(), which says that it deletes.',
  );
}

/// Serve a hit and break a write, with both channels wired.
Future<ProbeOutcome> _hitsAreReportable() async {
  final hits = <CacheHit>[];
  final failures = <CacheFailure>[];
  final adapter = ScriptedAdapter((options) => {'v': 1});

  final observed = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    cacheConfig: CacheConfig(
      strategy: CacheStrategy.cacheFirst,
      defaultTtl: const Duration(minutes: 10),
      onCacheHit: hits.add,
      onCacheError: failures.add,
    ),
    httpClientAdapter: adapter,
  );
  await observed.get<dynamic>('/config');
  await observed.get<dynamic>('/config');

  final broken = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    cacheConfig: CacheConfig(
      storage: _RefusingStorage(),
      strategy: CacheStrategy.networkFirst,
      onCacheHit: hits.add,
      onCacheError: failures.add,
    ),
    httpClientAdapter: ScriptedAdapter((options) => {'v': 2}),
  );
  await broken.get<dynamic>('/config');

  return ProbeOutcome(
    headline:
        '${hits.length} hit reported (stale: ${hits.firstOrNull?.isStale}), '
        '${failures.length} storage failure reported',
    detail:
        'A hit resolves before the logger, the metrics and the tracer, so none '
        'of them ever sees one — deliberate, since a cached response spent no '
        'time on the network. The cost is that your fastest requests are '
        'missing from every dashboard and the hit rate is unreadable. A '
        'refused write was worse: absorbed in silence, so a store that refuses '
        'everything leaves the client permanently cacheless with every request '
        'still succeeding.',
  );
}

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
