import 'dart:convert';

import 'package:apix/apix.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Exercises `SecureStorageService` against the **real** keychain / keystore.
///
/// Everything in apix's own suite runs against a `MockFlutterSecureStorage`
/// that throws exactly what the test tells it to. That proves the logic is
/// coherent; it cannot prove the premise. And the premise is a guess:
/// `_isBadPaddingException` decides whether to **delete a user's credentials**
/// by matching five substrings against a platform exception's `toString()`.
///
/// Both failure directions are silent, which is why this needs a device:
///
/// * **under-match** — the recovery never fires, the user stays stuck on an
///   unreadable token, and `read` rethrows a raw platform exception where the
///   contract promises `null`;
/// * **over-match** — sessions are wiped, indistinguishably from a normal
///   expiry.
///
/// ## How the corruption is staged, and why the previous attempt could not be
///
/// The first version of this file wrote under one `keyCipherAlgorithm` and read
/// under another. It never staged anything, and the reason is worth keeping:
/// `FlutterSecureStorage.initialize()` on Android returns immediately when its
/// `preferences` field is already set, so **the cipher is built once and every
/// later call inherits it**. The read was decrypting with the very key that had
/// encrypted it. No option changes that; only a fresh process does.
///
/// How far that reaches depends on the version, and both were measured:
///
/// * **10.0.0** (the declared floor) — one storage instance for the whole
///   process. The first call fixes the preferences file and the cipher for
///   everything; only the config is re-read per call, so `resetOnError` and the
///   key prefix still follow each call.
/// * **10.3.1** — the plugin keeps `storagesBySharedPreferencesName`, one
///   instance per store name, and the early return now precedes storing the
///   config. So the freeze is **per store**: the first call *for a given store*
///   fixes its cipher, its `resetOnError` and its key prefix, and a storage
///   naming a different store gets its own untouched instance.
///
/// What actually corrupts is reaching the bytes. `flutter_secure_storage` keeps
/// every value as Base64 ciphertext inside an **ordinary, unencrypted**
/// SharedPreferences file: the encryption protects the bytes, not the container.
/// So the probe flips one byte of that ciphertext through a native channel
/// (`apix.probe/prefs`, wired in `MainActivity.kt`) and asks apix to read it
/// back. AES-GCM authenticates what it decrypts, so a single flipped byte is a
/// genuine authentication failure — not a malformed input, which would raise
/// something else entirely and prove nothing about the substrings.
///
/// ## The instance cache dictates the shape of this file
///
/// Because the first call wins, **every** `FlutterSecureStorage` here passes the
/// same [probeStore] *and the same `resetOnError`*. Sharing a store while
/// disagreeing on options means the loser is measured under the winner's
/// settings and reported under its own — which is not a hypothetical: a group
/// asserting `resetOnError: true` ran under a `false` established above it and
/// reported `announced: 1` for a configuration that produces `announced: 0`.
///
/// So one file holds one configuration. `resetOnError: true` lives in
/// `secure_storage_reset_on_error_device_test.dart`, and `withBiometrics()` in
/// `secure_storage_biometric_device_test.dart` — the latter could never have
/// been measured here, since its options would arrive after the cipher is
/// built.
///
/// Nothing below calls `deleteAll()`, however isolated the probe store looks:
/// one test deliberately exercises the bare constructor, which names no store
/// and therefore may write beside the app's real session.
///
/// ## Running it
///
/// ```bash
/// # One device only: a phone plugged in beside the emulator silently wins.
/// flutter devices
/// flutter test integration_test/secure_storage_device_test.dart -d <id>
/// ```
///
/// Read the `DEVICE |` lines: they carry the verbatim platform messages, which
/// are the evidence this file exists to collect.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The preferences file every storage in this file points at, and the prefix
  /// the plugin puts in front of each key (`prefix + '_' + key`).
  const probeStore = 'apix_probe_store';
  const probePrefix = 'apix_probe';

  const probeKey = 'token';
  const storedKey = '${probePrefix}_$probeKey';
  const probeValue = 'value-from-device';

  /// Raw access to [probeStore], bypassing all encryption. See `MainActivity`.
  const rawPrefs = MethodChannel('apix.probe/prefs');

  Future<String?> rawRead(String file, String key) =>
      rawPrefs.invokeMethod<String>('read', {'file': file, 'key': key});

  Future<List<String>> rawKeys(String file) async {
    final keys = await rawPrefs.invokeListMethod<String>('keys', {
      'file': file,
    });
    return keys ?? const [];
  }

  Future<void> rawWrite(String file, String key, String value) async {
    final committed = await rawPrefs.invokeMethod<bool>('write', {
      'file': file,
      'key': key,
      'value': value,
    });
    expect(
      committed,
      isTrue,
      reason:
          'the native channel reported that the commit did not land, so '
          'nothing below is staged — this is the probe failing, not apix',
    );
  }

  FlutterSecureStorage probeStorage({bool resetOnError = false}) {
    return FlutterSecureStorage(
      // Passed identically everywhere: these options only bind on the first
      // call for a given store, so a caller that disagrees is silently served
      // the first caller's settings.
      //
      // `sharedPreferencesName` is deprecated from 10.3.0 in favour of
      // `storageNamespace`, which isolates the KeyStore aliases too and would
      // suit a probe better. It is kept because apix declares
      // `>=10.0.0 <11.0.0` and the replacement does not exist at that floor —
      // this file has to run against both bounds, which is the whole point of
      // measuring them.
      aOptions: AndroidOptions(
        resetOnError: resetOnError,
        // ignore: deprecated_member_use
        sharedPreferencesName: probeStore,
        preferencesKeyPrefix: probePrefix,
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  void report(String line) {
    // ignore: avoid_print
    print('DEVICE | $line');
  }

  /// Flips one byte of the ciphertext stored in [file] under [storedUnder].
  ///
  /// The write has to have happened already: which storage performed it, and
  /// therefore where it landed, is the variable the callers differ on. Doing it
  /// here would hide exactly that.
  ///
  /// Returns the corrupted Base64 so callers can prove the store changed.
  Future<String> corruptStoredValue(String file, String storedUnder) async {
    final stored = await rawRead(file, storedUnder);
    expect(
      stored,
      isNotNull,
      reason:
          'a value was written through the plugin and is not in $file under '
          '"$storedUnder". The staging is broken, and the usual cause is that '
          'the write went to a different store than the one being read — the '
          'plugin picks the store from options that only apply on the first '
          'call for that store. List `keys` on both before hunting for a '
          'defect in apix.',
    );

    // Java writes with Base64.DEFAULT, which wraps lines; Dart's decoder
    // rejects the newlines it inserts.
    final flat = stored!.replaceAll(RegExp(r'\s'), '');
    final bytes = base64.decode(flat);

    // One byte, in the middle of the ciphertext. GCM authenticates the whole
    // message, so this is a tag mismatch however small the edit — and a small
    // edit keeps the value structurally valid Base64 of a plausible length,
    // which a truncation or a random blob would not.
    bytes[bytes.length ~/ 2] ^= 0xFF;

    final corrupted = base64.encode(bytes);
    await rawWrite(file, storedUnder, corrupted);

    final readBack = await rawRead(file, storedUnder);
    expect(
      readBack,
      corrupted,
      reason:
          'the corrupted value did not survive the round-trip to the '
          'preferences file, so the staging did not stage',
    );
    expect(
      readBack,
      isNot(flat),
      reason: 'the stored ciphertext is unchanged: nothing was corrupted',
    );

    return corrupted;
  }

  /// **Never `deleteAll()`.** If the instance cache ever defeated the probe
  /// store, this runs against the device's real keychain beside the app's own
  /// session — and a probe that logs the user out to prove that logging the
  /// user out is detectable has stopped being a probe.
  tearDown(() async {
    try {
      await probeStorage().delete(key: probeKey);
    } catch (_) {
      // A key we cannot open is a key the recovery has already dropped.
    }
  });

  group('the real platform round-trips', () {
    testWidgets('write, read, containsKey, readAll, delete', (tester) async {
      final service = SecureStorageService(storage: probeStorage());

      await service.write(probeKey, probeValue);
      expect(
        await service.read(probeKey),
        probeValue,
        reason:
            'if this fails, nothing below means anything — the wrapper is '
            'not reaching the platform at all',
      );
      expect(await service.containsKey(probeKey), isTrue);
      expect((await service.readAll())[probeKey], probeValue);

      await service.delete(probeKey);
      expect(await service.read(probeKey), isNull);
      expect(await service.containsKey(probeKey), isFalse);

      report('round-trip OK on ${defaultTargetPlatform.name}');
    });

    testWidgets('the probe store is where the bytes actually land', (
      tester,
    ) async {
      await probeStorage().write(key: probeKey, value: probeValue);

      final keysHere = await rawKeys(probeStore);
      final keysDefault = await rawKeys('FlutterSecureStorage');

      report('$probeStore holds ${keysHere.length} key(s): $keysHere');
      report('default store holds ${keysDefault.length} key(s)');

      expect(
        keysHere,
        contains(storedKey),
        reason:
            'the whole file assumes sharedPreferencesName took effect. It only '
            'does on the first plugin call of the process, so if this fails '
            'every write here is landing in the app\'s real store and the '
            'corruption tests are editing someone\'s session.',
      );
      expect(
        keysDefault,
        isNot(contains(storedKey)),
        reason: 'the probe key must exist in exactly one store',
      );
    });

    testWidgets('an absent key is a miss, not a throw', (tester) async {
      final service = SecureStorageService(storage: probeStorage());
      expect(await service.read('apix_probe_never_written'), isNull);
    });
  });

  group('what the platform really throws when it cannot decrypt', () {
    testWidgets('captured verbatim, with resetOnError off', (tester) async {
      await probeStorage().write(key: probeKey, value: probeValue);
      await corruptStoredValue(probeStore, storedKey);

      Object? thrown;
      String? returned;
      try {
        returned = await probeStorage(resetOnError: false).read(key: probeKey);
      } catch (e) {
        thrown = e;
      }

      if (thrown == null) {
        report('resetOnError:false → NO THROW, read gave $returned');
        fail(
          'One byte of the stored ciphertext was flipped and the platform did '
          'not raise. Either the staging no longer produces a decryption '
          'failure — in which case THIS PROBE is what needs fixing, not apix — '
          'or the plugin now recovers even with resetOnError off, which would '
          "make apix's own recovery unreachable on this platform.",
        );
      }

      final message = thrown.toString();
      report('resetOnError:false → ${thrown.runtimeType}: $message');

      // The five substrings apix matches on. Named here rather than imported:
      // this test exists to check them against reality, so reading them from
      // the code under test would only prove the code agrees with itself.
      const recognised = [
        'bad padding',
        'badpaddingexception',
        'pad block corrupted',
        'bad_decrypt',
        'error:1e000065',
      ];
      final lower = message.toLowerCase();
      final matched = recognised.where(lower.contains).toList();

      report('matched substrings: ${matched.isEmpty ? "NONE" : matched}');

      expect(
        matched,
        isNotEmpty,
        reason:
            'apix deletes a credential when it recognises this message, and '
            'recognises none of it. Every unit test around '
            '_isBadPaddingException passes while the door never opens: a real '
            'corruption would rethrow a raw platform exception where the '
            'contract promises null. Add the real substring above to '
            'SecureStorageService, and to the corpus in '
            'apix/test/auth/secure_storage_recovery_test.dart.',
      );
    });

    testWidgets('and apix therefore recovers, and says so', (tester) async {
      await probeStorage().write(key: probeKey, value: probeValue);
      await corruptStoredValue(probeStore, storedKey);

      final announced = <SecureStorageRecovery>[];
      final service = SecureStorageService(
        storage: probeStorage(resetOnError: false),
        onBeforeRecoveryDelete: announced.add,
      );

      final value = await service.read(probeKey);

      report('apix read → $value · announced ${announced.length} recovery');

      expect(
        value,
        isNull,
        reason:
            'the contract is that an unreadable entry is a miss, never a '
            'throw — this is the end-to-end version of the assertion above',
      );
      expect(
        announced,
        hasLength(1),
        reason:
            'the channel a consumer asked for has to fire on the real '
            'trigger, not only on the mocked one',
      );
      expect(announced.single.operation, SecureStorageOperation.read);
      expect(announced.single.key, probeKey);
      expect(announced.single.isFullWipe, isFalse);
    });

    testWidgets('the constructor a consumer actually calls announces too', (
      tester,
    ) async {
      // Every assertion above injects a storage this file built, so all of
      // them would keep passing if SecureStorageService's own default went
      // back to the plugin's `resetOnError: true` — the code under test would
      // never be reached. This is the one that exercises the default, and it
      // is the reason the default was changed.
      //
      // ⚠️ This one cannot be isolated, and that is not an oversight: a bare
      // constructor names no store, so wherever it writes IS the measurement.
      // Which store that is depends on the plugin version — at the floor a
      // single instance serves the whole process, so it inherits the probe
      // store; from 10.3.0 the plugin keeps one instance per store name and the
      // bare constructor gets the real, default one. Both were measured.
      //
      // So both the store and the key are derived rather than spelled out, and
      // the key is deliberately unlike anything an app would store, since on
      // half the versions this runs beside the real session. Nothing here
      // deletes more than the one entry it created.
      const bareKey = 'apix_bare_constructor_probe';

      final announced = <SecureStorageRecovery>[];
      final service = SecureStorageService(
        onBeforeRecoveryDelete: announced.add,
      );

      await service.write(bareKey, probeValue);

      const candidateStores = [probeStore, 'FlutterSecureStorage'];
      final landed = <({String store, String key})>[
        for (final store in candidateStores)
          for (final key in await rawKeys(store))
            if (key.endsWith('_$bareKey')) (store: store, key: key),
      ];

      report('bare write landed in: $landed');

      expect(
        landed,
        hasLength(1),
        reason:
            'expected the bare constructor to write exactly one entry ending '
            'in "_$bareKey" across $candidateStores, found $landed. None means '
            'it wrote somewhere this probe does not look; more than one means '
            'a previous run left an entry behind, and corrupting the wrong one '
            'would prove nothing.',
      );

      await corruptStoredValue(landed.single.store, landed.single.key);

      Object? thrown;
      String? value;
      try {
        value = await service.read(bareKey);
      } catch (e) {
        thrown = e;
      }

      report(
        'bare constructor → value=$value thrown=$thrown '
        'announced=${announced.length}',
      );

      expect(
        thrown,
        isNull,
        reason: 'a corrupted entry must not surface as an exception',
      );
      expect(
        value,
        isNull,
        reason:
            'nor as a value. A non-null answer means the plugin handed back '
            'one of its own status strings — FlutterSecureStoragePlugin '
            'returns the literal "Data has been reset" on some paths — which '
            'apix would pass off as a token.',
      );
      expect(
        announced,
        hasLength(1),
        reason:
            'the default configuration destroyed a credential without '
            'telling anyone. That is what resetOnError: false exists to '
            'prevent: under the plugin default this list is empty, every '
            'other test here still passes, and the a review point channel is dead for '
            'everyone who did not configure their way out of it.',
      );
      expect(announced.single.key, bareKey);
      expect(announced.single.isFullWipe, isFalse);

      await service.delete(bareKey);
    });

    // The `resetOnError: true` counterpart — what a consumer who opts back into
    // the plugin's own default gets — lived here until 12 Aug 2026. It cannot:
    // from plugin 10.3.0 the first call of the process fixes resetOnError for
    // every later one, so a second configuration in the same file measures the
    // first one and reports it as the second. It reported `announced: 1` for a
    // configuration that produces `announced: 0`.
    //
    // It now has its own process, in secure_storage_reset_on_error_device_test
    // .dart. One file, one configuration — the same rule that split the
    // biometric probe off.
    testWidgets('an absent key is still a miss after all this', (tester) async {
      expect(
        await SecureStorageService(storage: probeStorage()).read('nope'),
        isNull,
      );
    });
  });
}
