import 'package:apix/apix.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Settles one question `secure_storage_device_test.dart` structurally cannot:
/// does `SecureStorageService.withBiometrics()` enforce anything?
///
/// ## Why this needs a file of its own
///
/// `FlutterSecureStorage.initialize()` on Android returns immediately once its
/// `preferences` field is set, so **the first plugin call of the process builds
/// the cipher and every later call inherits it** — options and all. A biometric
/// test that runs after any other storage call therefore measures the cipher
/// somebody else built, and reports whatever that one does.
///
/// That is not hypothetical. apix's dartdoc currently states that
/// `withBiometrics()` degrades silently, on the strength of a test that ran
/// fourth in its file. One file is one process is one first initialisation;
/// that is the whole reason this file exists, and why nothing may be added
/// above the first group.
///
/// ## Isolation, obtained from the same cache
///
/// The trap doubles as the safety net. [_boot] takes the first call with the
/// factory's own options **plus** a dedicated preferences file, so the factory
/// under test — which cannot name a store — inherits an isolated one instead of
/// writing beside the app's real session. `rawKeys` proves it landed there.
///
/// ## Running it
///
/// ```bash
/// adb shell locksettings get-disabled          # true → no credential
/// adb shell dumpsys fingerprint | grep -i enrolled
/// flutter test integration_test/secure_storage_biometric_device_test.dart \
///   -d <id> --dart-define=APIX_DEVICE_HAS_CREDENTIAL=true
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const probeStore = 'apix_biometric_probe_store';
  const probePrefix = 'apix_probe';
  const probeKey = 'biometric';
  const storedKey = '${probePrefix}_$probeKey';

  const rawPrefs = MethodChannel('apix.probe/prefs');

  Future<List<String>> rawKeys(String file) async {
    final keys = await rawPrefs.invokeListMethod<String>('keys', {
      'file': file,
    });
    return keys ?? const [];
  }

  /// Whether this device has a lock screen or an enrolled biometric. Passed in
  /// rather than detected: Dart cannot see it, and a probe that guesses the
  /// state it is measuring against is measuring nothing.
  const hasCredential = bool.fromEnvironment('APIX_DEVICE_HAS_CREDENTIAL');

  void report(String line) {
    // ignore: avoid_print
    print('DEVICE | $line');
  }

  /// The options `SecureStorageService.withBiometrics()` passes, plus a store
  /// of our own. Must be the first storage call the process makes.
  FlutterSecureStorage boot() {
    return FlutterSecureStorage(
      // `sharedPreferencesName` is deprecated from 10.3.0 in favour of
      // `storageNamespace`, which does not exist at the floor apix declares
      // (`>=10.0.0`). This probe has to run against both bounds.
      aOptions: const AndroidOptions.biometric(
        enforceBiometrics: true,
        // Mirrors what the factory passes. It is what turns the broken state
        // below into an exception instead of a silent deleteAll().
        resetOnError: false,
        biometricPromptTitle: 'apix device probe',
        biometricPromptSubtitle: 'Staging a biometric-backed write',
        // ignore: deprecated_member_use
        sharedPreferencesName: probeStore,
        preferencesKeyPrefix: probePrefix,
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
        accessControlFlags: [AccessControlFlag.userPresence],
      ),
    );
  }

  group('withBiometrics is more than a constructor', () {
    testWidgets(
      'enforceBiometrics with nothing to enforce against '
      '(skipped on a device that has a credential)',
      skip: hasCredential,
      (tester) async {
        // This is the first plugin call of the process, so it is the one that
        // builds the cipher — and therefore the only one that can reach the
        // enforcement check at all.
        Object? failure;
        var completed = false;
        try {
          await boot()
              .write(key: probeKey, value: 'value')
              .timeout(const Duration(seconds: 8));
          completed = true;
        } on TimeoutException {
          report(
            'enforced write → blocking prompt on a device with no '
            'credential, which should be impossible',
          );
          fail(
            'A prompt appeared although the device reports no credential. '
            'Either APIX_DEVICE_HAS_CREDENTIAL is wrong for this device — in '
            'which case THIS PROBE is misconfigured — or the platform is '
            'prompting for something it cannot satisfy.',
          );
        } catch (e) {
          failure = e;
        }

        report('enforced write → completed=$completed failure=$failure');

        if (failure != null) {
          // The plugin's own contract: enforceBiometrics=true must refuse when
          // there is no PIN, pattern, password or enrolled biometric.
          //
          // Asserted on the ROOT CAUSE, because the surface message depends on
          // what the previous run left behind and reads like a regression when
          // it changes. Measured 12 Aug 2026, same device, same binary:
          //
          //   first run, virgin store → "BIOMETRIC_UNAVAILABLE: ..."
          //   every run after         → "Migration failed after algorithm
          //                              change", with BIOMETRIC_UNAVAILABLE
          //                              two `Caused by:` down
          //
          // The algorithm markers persist across runs, so the second run finds
          // a store to migrate before it gets to refuse. Both are the same
          // refusal; only one of them says so in its first line.
          expect(
            failure.toString(),
            contains('BIOMETRIC_UNAVAILABLE'),
            reason:
                'the write was refused, which is the documented behaviour, but '
                'not for the documented reason — neither the message nor any '
                'of its causes names the missing credential',
          );
          report('enforcement is ACTIVE: the platform refused');
          return;
        }

        // It returned on a device with nothing to authenticate against. That is
        // the silent degradation apix documents — pinned here so the day a
        // plugin release starts enforcing, this goes red and the documentation
        // is what needs changing.
        final readBack = await boot().read(key: probeKey);
        report('degraded silently → read back: $readBack');

        expect(
          readBack,
          'value',
          reason:
              'the write reported success, so the value has to exist. A silent '
              'no-op is the one outcome that would make withBiometrics() a '
              'factory that looks like protection and is not.',
        );
      },
    );

    testWidgets('what the refusal leaves behind, and how loudly', (
      tester,
    ) async {
      // The refusal above is not the end of it. The plugin assigns its
      // `preferences` field before the cipher it failed to build, so this call
      // short-circuits initialisation and finds no cipher — confirmed in
      // logcat:
      //
      //   NullPointerException: StorageCipher.encrypt(byte[]) on a null object
      //     at FlutterSecureStorage.writeUnsafe(:130)
      //     at FlutterSecureStorage.initialize(:151)   ← the cached early return
      //
      // Under the plugin's own `resetOnError: true` that becomes deleteAll()
      // reported to Dart as a SUCCESS: an app that catches BIOMETRIC_UNAVAILABLE
      // and carries on empties its entire secure store believing it wrote.
      // apix passes resetOnError: false so it raises instead, which is what
      // this pins.
      final service = SecureStorageService.withBiometrics();

      Object? failure;
      String? readBack;
      try {
        await service
            .write(probeKey, 'from-the-factory')
            .timeout(const Duration(seconds: 8));
        readBack = await service.read(probeKey);
      } on TimeoutException {
        report('factory → prompt is blocking: enforcement is ACTIVE');
        return;
      } catch (e) {
        failure = e;
      }

      report('factory → failure=$failure readBack=$readBack');

      final keysDefault = await rawKeys('FlutterSecureStorage');
      report('$probeStore holds: ${await rawKeys(probeStore)}');

      expect(
        keysDefault,
        isNot(contains(storedKey)),
        reason:
            'the factory cannot name a store, so it relies on boot() having '
            'claimed one first. If the probe key is in the default store, '
            'this file is writing beside the app\'s real session and the '
            'isolation described at the top does not hold.',
      );

      if (hasCredential) {
        // Nothing was refused, so nothing is broken: the ordinary path.
        expect(failure, isNull);
        expect(readBack, 'from-the-factory');
        return;
      }

      expect(
        failure,
        isNotNull,
        reason:
            'the write returned instead of raising. Either the plugin no '
            'longer leaves a null cipher behind a refused enforcement — in '
            'which case this expectation is what needs updating — or apix has '
            'stopped passing resetOnError: false, and a failed write is once '
            'again wiping the whole store while reporting success.',
      );
      expect(
        readBack,
        isNull,
        reason: 'the write raised, so nothing can have been stored',
      );
    });
  });

  tearDown(() async {
    try {
      await boot().delete(key: probeKey);
    } catch (_) {
      // A key we cannot open is a key that is already gone for our purposes.
    }
  });
}
