import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `flutter_secure_storage`'s files must stay out of Android backup.
///
/// Restored without the Keystore key that wrapped their key — which never
/// leaves the device — they leave the plugin unusable on every launch:
/// `Migration failed after algorithm change (Invalid key, key type incompatible
/// with cipher)`, measured on an Android 11 (API 30) emulator at plugin 10.3.1
/// and 11.2.0. Nothing at runtime notices the rules are gone: the app works
/// until its first restore, on somebody's new phone. So this reads the
/// configuration that ships.
void main() {
  const manifest = 'android/app/src/main/AndroidManifest.xml';
  const legacyRules =
      'android/app/src/main/res/xml/secure_storage_backup_rules.xml';
  const rules =
      'android/app/src/main/res/xml/secure_storage_data_extraction_rules.xml';

  /// The default store's files, as the plugin names them: the three a restore
  /// brought back in that measurement, and the marker file 10.0.0 wrote before
  /// markers moved per store.
  const storeFiles = {
    'FlutterSecureStorage.xml',
    'FlutterSecureKeyStorage.xml',
    'FlutterSecureStorageConfiguration.xml',
    'FlutterSecureStorageConfiguration:FlutterSecureStorage.xml',
  };

  // The rule files explain themselves in XML comments that quote the same
  // element; a match in a comment excludes nothing.
  String withoutComments(String xml) =>
      xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  Set<String> excludedPrefs(String xml) => RegExp(
    r'<exclude\s+domain="sharedpref"\s+path="([^"]+)"\s*/>',
  ).allMatches(xml).map((m) => m.group(1)!).toSet();

  String read(String path) => withoutComments(File(path).readAsStringSync());

  test('the manifest hands both backup mechanisms the rules', () {
    final application = RegExp(
      r'<application\b[^>]*>',
    ).firstMatch(read(manifest))?.group(0);

    expect(application, isNotNull, reason: 'no <application> in $manifest');
    expect(
      application,
      contains('android:fullBackupContent="@xml/secure_storage_backup_rules"'),
      reason: 'Android 11 and lower read fullBackupContent',
    );
    expect(
      application,
      contains(
        'android:dataExtractionRules='
        '"@xml/secure_storage_data_extraction_rules"',
      ),
      reason: 'Android 12 and later read dataExtractionRules instead',
    );
  });

  test('Android 11 and lower exclude every file of the store', () {
    expect(excludedPrefs(read(legacyRules)), equals(storeFiles));
  });

  for (final section in ['cloud-backup', 'device-transfer']) {
    test('Android 12 and later exclude every file of the store from '
        '$section', () {
      final body = RegExp(
        '<$section>(.*?)</$section>',
        dotAll: true,
      ).firstMatch(read(rules))?.group(1);

      expect(body, isNotNull, reason: 'no <$section> section in $rules');
      expect(excludedPrefs(body!), equals(storeFiles));
    });
  }
}
