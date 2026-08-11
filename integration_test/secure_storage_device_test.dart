import 'package:apix/apix.dart';
import 'package:flutter/foundation.dart';
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
/// ## The question this was written to settle
///
/// `AndroidOptions` defaults to **`resetOnError: true`**, and apix inherits
/// that default. If the plugin resets the store itself, apix's recovery never
/// sees an exception at all — and five substrings, a callback and twenty-five
/// unit tests would be guarding a door that does not open on Android.
///
/// ## It stages its own corruption
///
/// No adb, no reinstall, no restored backup. Writing under one cipher and
/// reading under another with `migrateOnAlgorithmChange: false` produces a real
/// decryption failure, which is the same class of event as a keystore key lost
/// to a restore. That is what makes this an assertion rather than a report.
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

  /// Every key this file writes. Isolation is by **key**, not by namespace:
  /// `storageNamespace` does not exist at the floor of the range apix declares
  /// (`flutter_secure_storage >=10.0.0`), and this app resolves that floor.
  const probeKeys = ['apix_probe_token', 'apix_probe_biometric'];

  /// **Never `deleteAll()`.** This runs against the device's real keychain,
  /// beside the app's own session — a probe that wipes the store to clean up
  /// after itself logs the user out to prove that logging the user out is
  /// detectable.
  Future<void> removeProbeKeys(FlutterSecureStorage storage) async {
    for (final key in probeKeys) {
      try {
        await storage.delete(key: key);
      } catch (_) {
        // A key we cannot open is a key the recovery has already dropped.
      }
    }
  }

  FlutterSecureStorage plain({
    bool resetOnError = true,
    KeyCipherAlgorithm keyCipher =
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
  }) {
    return FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: resetOnError,
        migrateOnAlgorithmChange: false,
        keyCipherAlgorithm: keyCipher,
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

  tearDown(() async => removeProbeKeys(plain()));

  group('the real platform round-trips', () {
    testWidgets('write, read, containsKey, readAll, delete', (tester) async {
      final service = SecureStorageService(storage: plain());

      await service.write('apix_probe_token', 'value-from-device');
      expect(
        await service.read('apix_probe_token'),
        'value-from-device',
        reason:
            'if this fails, nothing below means anything — the wrapper is '
            'not reaching the platform at all',
      );
      expect(await service.containsKey('apix_probe_token'), isTrue);
      expect(
        (await service.readAll())['apix_probe_token'],
        'value-from-device',
        reason:
            "asserted by lookup, never by length: the app's own session "
            'lives in this same store',
      );

      await service.delete('apix_probe_token');
      expect(await service.read('apix_probe_token'), isNull);
      expect(await service.containsKey('apix_probe_token'), isFalse);

      // `deleteAll()` is deliberately not exercised. It is the one call in this
      // API that would take the app's real session with it, and a probe that
      // logs the user out to demonstrate that logging the user out is
      // detectable has stopped being a probe.
      report('round-trip OK on ${defaultTargetPlatform.name}');
    });

    testWidgets('an absent key is a miss, not a throw', (tester) async {
      final service = SecureStorageService(storage: plain());
      expect(await service.read('apix_probe_never_written'), isNull);
    });
  });

  group('what the platform really throws when it cannot decrypt', () {
    /// Writes under one key cipher, then reads under another with migration
    /// off — a genuine decryption failure, staged from Dart.
    Future<Object?> stageCorruptionAndRead({required bool resetOnError}) async {
      await plain(
        keyCipher: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      ).write(key: 'apix_probe_token', value: 'value-from-device');

      final rotated = plain(
        resetOnError: resetOnError,
        keyCipher: KeyCipherAlgorithm.AES_GCM_NoPadding,
      );
      try {
        final value = await rotated.read(key: 'apix_probe_token');
        return _NoThrow(value);
      } catch (e) {
        return e;
      }
    }

    testWidgets('captured verbatim, with resetOnError off', (tester) async {
      final outcome = await stageCorruptionAndRead(resetOnError: false);

      if (outcome is _NoThrow) {
        report('resetOnError:false → NO THROW, read gave ${outcome.value}');
        fail(
          'The corruption was staged and the platform did not raise. Either '
          'the staging no longer produces a decryption failure — in which case '
          'THIS TEST is what needs fixing, not the code — or the plugin now '
          'recovers even with resetOnError off, which would make apix\'s own '
          'recovery unreachable on this platform.',
        );
      }

      final message = outcome.toString();
      report('resetOnError:false → ${outcome.runtimeType}: $message');

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
            'apix deletes a credential when it recognises this message, '
            'and recognises none of it. Every unit test around '
            '_isBadPaddingException passes while the door never opens: a real '
            'corruption would rethrow a raw platform exception where the '
            'contract promises null. Add the real substring above to '
            'SecureStorageService, and to the corpus in '
            'apix/test/auth/secure_storage_recovery_test.dart.',
      );
    });

    testWidgets('and apix therefore recovers, and says so', (tester) async {
      final announced = <SecureStorageRecovery>[];

      await plain(
        keyCipher: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      ).write(key: 'apix_probe_token', value: 'value-from-device');

      final service = SecureStorageService(
        storage: plain(
          resetOnError: false,
          keyCipher: KeyCipherAlgorithm.AES_GCM_NoPadding,
        ),
        onBeforeRecoveryDelete: announced.add,
      );

      final value = await service.read('apix_probe_token');

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
      expect(announced.single.key, 'apix_probe_token');
      expect(announced.single.isFullWipe, isFalse);
    });

    testWidgets('resetOnError:true — does apix ever see the failure?', (
      tester,
    ) async {
      // apix's own default. If the plugin absorbs the corruption here, the
      // recovery path is unreachable in the configuration consumers get out of
      // the box — which is worth knowing even though it is not a failure.
      final outcome = await stageCorruptionAndRead(resetOnError: true);

      if (outcome is _NoThrow) {
        report(
          'resetOnError:true → plugin absorbed it, read gave '
          '${outcome.value} — apix\'s recovery never runs in this config',
        );
      } else {
        report('resetOnError:true → still throws: $outcome');
      }

      // Deliberately no assertion: both outcomes are legitimate, and pinning
      // the one observed today would freeze a plugin behaviour apix does not
      // own. The `DEVICE |` line is the deliverable.
    });
  });

  group('withBiometrics is more than a constructor', () {
    testWidgets('an enforced write does not silently succeed without auth', (
      tester,
    ) async {
      final service = SecureStorageService.withBiometrics(
        biometricPromptTitle: 'apix device probe',
        biometricPromptSubtitle: 'Staging a biometric-backed write',
      );

      // A satisfiable prompt blocks forever in an integration test, and that
      // is itself the answer: the enforcement is active. Anything that returns
      // fast is either a refusal or a silent no-op, and only the second is a
      // defect.
      Object? failure;
      var completed = false;
      try {
        await service
            .write('apix_probe_biometric', 'value')
            .timeout(const Duration(seconds: 8));
        completed = true;
      } on TimeoutException {
        report('withBiometrics → prompt is blocking: enforcement is ACTIVE');
        return;
      } catch (e) {
        failure = e;
      }

      if (failure != null) {
        report('withBiometrics → refused: $failure');
        return;
      }

      // It returned. The only acceptable reading is that this device has an
      // enrolled credential and the platform satisfied the prompt without UI —
      // in which case the value must actually be there.
      expect(completed, isTrue);
      final readBack = await service
          .read('apix_probe_biometric')
          .timeout(const Duration(seconds: 8), onTimeout: () => null);

      report('withBiometrics → wrote and read back: $readBack');
      expect(
        readBack,
        'value',
        reason:
            'the write reported success, so the value has to exist. A '
            'silent no-op is the one outcome that would make '
            'SecureStorageService.withBiometrics() a factory that looks like '
            'protection and is not.',
      );

      await service.delete('apix_probe_biometric');
    });
  });
}

/// Marks "the read returned instead of throwing", so the two cases stay
/// distinguishable when the returned value is itself `null`.
class _NoThrow {
  const _NoThrow(this.value);
  final String? value;

  @override
  String toString() => '_NoThrow($value)';
}
