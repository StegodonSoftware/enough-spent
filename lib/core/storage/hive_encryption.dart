import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages the AES-256 encryption key for Hive boxes.
///
/// Key is generated once, stored in the Android Keystore via
/// flutter_secure_storage, and reloaded on every subsequent launch.
///
/// ─── TO REMOVE ENCRYPTION ─────────────────────────────────────────────────
///   1. Delete this file.
///   2. In main.dart: remove the "ENCRYPTION" block and the
///      `encryptionCipher: hiveCipher` argument from all Hive.openBox() calls.
///   3. Remove `flutter_secure_storage` from pubspec.yaml.
///   NOTE: Existing encrypted data will be unreadable after removal. Users
///   will need to clear app data or reinstall to start fresh.
/// ──────────────────────────────────────────────────────────────────────────
class HiveEncryption {
  static const _keyName = 'hive_encryption_key';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  /// Returns a cipher backed by a key in the Android Keystore.
  /// Generates and persists a new 256-bit key on the first call.
  static Future<HiveAesCipher> getCipher() async {
    final existingKey = await _storage.read(key: _keyName);
    if (existingKey != null) {
      return HiveAesCipher(base64Url.decode(existingKey));
    }

    final key = Hive.generateSecureKey();
    await _storage.write(key: _keyName, value: base64Url.encode(key));
    return HiveAesCipher(key);
  }
}
