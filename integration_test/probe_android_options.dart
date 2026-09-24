import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android options that name the probe's own preferences store, at **both**
/// bounds of the plugin range apix declares (`>=10.0.0 <12.0.0`).
///
/// No public parameter compiles across that range: `sharedPreferencesName` was
/// removed from the Dart API in 11.0, and `storageNamespace`, its replacement,
/// does not exist at 10.0.0. The Android side takes the store name from the
/// options map, and at 11.2.0 it still reads the `sharedPreferencesName` key
/// there (`FlutterSecureStorageConfig.PREF_OPTION_NAME`) — so the probes write
/// that key themselves, and keep the store their raw-preferences channel
/// reaches into.
///
/// Each probe checks where its writes landed before trusting a measurement: a
/// store name that did not take effect would put the corruption tests inside
/// the app's real session.
class ProbeAndroidOptions extends AndroidOptions {
  /// The plain options, with the probe's [store].
  const ProbeAndroidOptions({
    required this.store,
    super.resetOnError,
    super.preferencesKeyPrefix,
  });

  /// `AndroidOptions.biometric`, with the probe's [store].
  const ProbeAndroidOptions.biometric({
    required this.store,
    super.enforceBiometrics,
    super.resetOnError,
    super.biometricPromptTitle,
    super.biometricPromptSubtitle,
    super.preferencesKeyPrefix,
  }) : super.biometric();

  /// The preferences file every storage built with these options writes to.
  final String store;

  @override
  Map<String, String> toMap() => {
    ...super.toMap(),
    'sharedPreferencesName': store,
  };
}
