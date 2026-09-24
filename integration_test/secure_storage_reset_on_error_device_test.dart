import 'dart:convert';

import 'package:apix/apix.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'probe_android_options.dart';

/// Measures what apix's default buys, by running without it.
///
/// `SecureStorageService` passes `resetOnError: false`. This file is the same
/// corruption, staged the same way, against a storage that keeps the plugin's
/// own `resetOnError: true` — the configuration a consumer gets back the moment
/// they inject their own `FlutterSecureStorage` without thinking about it.
///
/// The expected outcome is a **silence**: the read still answers `null`, every
/// contract holds, and `onBeforeRecoveryDelete` never fires while a credential
/// is destroyed. That is the failure mode the default exists to prevent, and
/// nothing in apix's own suite can see it — a mock throws what the test tells
/// it to, so the plugin's interception is invisible there.
///
/// ## Why it is not a group in the other file
///
/// It was, until 12 Aug 2026, and it lied. From plugin **10.2.0** the early
/// return in `initialize()` happens *before* the incoming config is stored, so
/// the first call **for a given store** fixes that store's `resetOnError` and
/// key prefix for every later one. Two storages naming the same store cannot
/// disagree: the second is measured under the first's settings and reported
/// under its own. Measured on 10.3.1 — the group asserting `resetOnError: true`
/// ran under the `false` established above it and reported `announced: 1` for a
/// configuration that produces `announced: 0`.
///
/// (The freeze is per store because from 10.2.0 the plugin keeps one instance
/// per store name — per store and key prefix from 11.2.0 — in
/// `storagesBySharedPreferencesName`. At the 10.0.0 floor there is a single
/// instance for the whole process, but the config is re-read on every call, so
/// the same file passed honestly there. Neither version lets one process hold
/// two `resetOnError` values for one store.)
///
/// One file is one process is one configuration. That rule now governs all
/// three device probes.
///
/// ```bash
/// flutter test integration_test/secure_storage_reset_on_error_device_test.dart -d <id>
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const probeStore = 'apix_reset_probe_store';
  const probePrefix = 'apix_reset';
  const probeKey = 'token';
  const storedKey = '${probePrefix}_$probeKey';
  const probeValue = 'value-from-device';

  const rawPrefs = MethodChannel('apix.probe/prefs');

  Future<String?> rawRead(String key) =>
      rawPrefs.invokeMethod<String>('read', {'file': probeStore, 'key': key});

  Future<List<String>> rawKeys() async {
    final keys = await rawPrefs.invokeListMethod<String>('keys', {
      'file': probeStore,
    });
    return keys ?? const [];
  }

  void report(String line) {
    // ignore: avoid_print
    print('DEVICE | $line');
  }

  /// The plugin's own default, which apix deliberately does not use.
  FlutterSecureStorage pluginDefaultStorage() {
    return FlutterSecureStorage(
      // The store is named through [ProbeAndroidOptions]: no public parameter
      // compiles at both bounds, and this probe has to run against both.
      aOptions: const ProbeAndroidOptions(
        store: probeStore,
        resetOnError: true,
        preferencesKeyPrefix: probePrefix,
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  testWidgets('the plugin repairs it first, and nobody is told', (
    tester,
  ) async {
    final announced = <SecureStorageRecovery>[];
    final service = SecureStorageService(
      storage: pluginDefaultStorage(),
      onBeforeRecoveryDelete: announced.add,
    );

    await service.write(probeKey, probeValue);

    final stored = await rawRead(storedKey);
    expect(
      stored,
      isNotNull,
      reason:
          'the value is not in $probeStore under "$storedKey", so nothing '
          'below is staged. This is the probe failing, not apix — check '
          'whether another storage call beat it to the first initialisation.',
    );

    final flat = stored!.replaceAll(RegExp(r'\s'), '');
    final bytes = base64.decode(flat);
    bytes[bytes.length ~/ 2] ^= 0xFF;
    final corrupted = base64.encode(bytes);

    final committed = await rawPrefs.invokeMethod<bool>('write', {
      'file': probeStore,
      'key': storedKey,
      'value': corrupted,
    });
    expect(committed, isTrue, reason: 'the corruption did not commit');
    expect(
      await rawRead(storedKey),
      isNot(flat),
      reason: 'the stored ciphertext is unchanged: nothing was corrupted',
    );

    Object? thrown;
    String? value;
    try {
      value = await service.read(probeKey);
    } catch (e) {
      thrown = e;
    }

    report(
      'plugin default → value=$value thrown=$thrown '
      'announced=${announced.length}',
    );
    report('after the read, $probeStore holds: ${await rawKeys()}');

    // The contract still holds — which is the whole problem. Nothing here is
    // wrong from the caller's side, so nothing would ever surface.
    expect(thrown, isNull);
    expect(
      value,
      isNull,
      reason:
          'a non-null answer would mean the plugin handed back one of its own '
          'status strings — it returns the literal "Data has been reset" on '
          'some paths — which apix would pass off as a token',
    );

    expect(
      announced,
      isEmpty,
      reason:
          'the channel fired under the plugin default, which would mean the '
          'plugin stopped intercepting — good news, but it makes the reason '
          'apix passes resetOnError: false obsolete, and the dartdoc on '
          'SecureStorageService says the opposite. Re-measure before trusting '
          'either.',
    );
    expect(
      await rawRead(storedKey),
      isNull,
      reason:
          'the entry survived, so nothing was destroyed and this probe is no '
          'longer demonstrating a silent deletion',
    );
  });
}
