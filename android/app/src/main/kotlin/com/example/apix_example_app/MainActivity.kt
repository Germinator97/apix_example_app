package com.example.apix_example_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Raw access to a named SharedPreferences file, for the device probe only.
 *
 * `flutter_secure_storage` stores every value as Base64 ciphertext inside an
 * ordinary, unencrypted SharedPreferences file — the encryption protects the
 * bytes, not the container. That is the only place a test can reach in to stage
 * a genuine decryption failure.
 *
 * Asking for a different cipher on read cannot do it: `initialize()` returns
 * early once the plugin holds its preferences, so the cipher built by the first
 * call serves every later one and the read decrypts with the key that wrote.
 * No option changes that — only a fresh process does.
 *
 * So the probe reads the stored Base64, flips one byte of the ciphertext, writes
 * it back, and asks apix to read it. That is a real authentication-tag failure,
 * not a malformed input — the difference matters, because the two do not raise
 * the same exception, and the exception's text is what apix matches on to decide
 * whether to delete a user's credentials.
 *
 * See `integration_test/secure_storage_device_test.dart`, which is the only
 * caller. Nothing in the demo app itself uses this channel.
 */
private const val PROBE_CHANNEL = "apix.probe/prefs"

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROBE_CHANNEL)
            .setMethodCallHandler { call, result ->
                val file = call.argument<String>("file")
                if (file.isNullOrEmpty()) {
                    result.error("missing_file", "A preferences file name is required", null)
                    return@setMethodCallHandler
                }
                val prefs = applicationContext.getSharedPreferences(file, Context.MODE_PRIVATE)

                when (call.method) {
                    "keys" -> result.success(prefs.all.keys.toList())

                    "read" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrEmpty()) {
                            result.error("missing_key", "A key is required", null)
                        } else {
                            // Absent and present-but-null are the same miss here:
                            // the probe only ever reads keys it has just written.
                            result.success(prefs.getString(key, null))
                        }
                    }

                    "write" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key.isNullOrEmpty() || value == null) {
                            result.error("missing_argument", "Both key and value are required", null)
                        } else {
                            // commit(), never apply(): the probe reads this file back
                            // through another plugin on another thread microseconds
                            // later, and needs the write to have landed by then.
                            val written = prefs.edit().putString(key, value).commit()
                            result.success(written)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
